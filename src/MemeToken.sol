// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";

 
contract MemeToken is ERC20, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ===== 配置与状态 =====
    uint16 public taxBps;
    address public taxWallet;
    mapping(address => bool) public isFeeExempt;

    uint256 public maxTxAmount;
    uint32 public maxDailyTxCount;
    mapping(address => uint32) public dailyCount;
    mapping(address => uint256) public lastReset;
    mapping(address => bool) public isLimitExempt;

    bool public tradingEnabled;

    IUniswapV2Router02 public router;
    address public pair;
    address public WETH;
    bool public swapAndLiquifyEnabled;
    uint256 public swapThreshold;
    bool private inSwap;

    EnumerableSet.AddressSet private liquidityPairs;

    error TradingNotEnabled();
    error MaxTxExceeded(uint256 amount, uint256 max);
    error DailyTxLimitExceeded(address account, uint32 max);
    error ZeroAddress();

    event SetTax(uint16 bps);
    event SetTaxWallet(address wallet);
    event SetMaxTxAmount(uint256 amount);
    event SetMaxDailyTxCount(uint32 count);
    event SetTradingEnabled(bool enabled);
    event SetSwapAndLiquify(bool enabled, uint256 threshold);
    event SetFeeExempt(address account, bool exempt);
    event SetLimitExempt(address account, bool exempt);
    event RouterAndPairSet(address router, address pair);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address router_,
        uint16 taxBps_,
        address taxWallet_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        if (router_ == address(0) || taxWallet_ == address(0)) revert ZeroAddress();

        _mint(msg.sender, totalSupply_);

        router = IUniswapV2Router02(router_);
        WETH = router.WETH();
        address factory = router.factory();
        pair = IUniswapV2Factory(factory).createPair(address(this), WETH);

        liquidityPairs.add(pair);

        taxBps = taxBps_;
        taxWallet = taxWallet_;

        maxTxAmount = (totalSupply_ * 2) / 100;
        maxDailyTxCount = 50;
        swapThreshold = totalSupply_ / 1000;
        swapAndLiquifyEnabled = true;

        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;
        isFeeExempt[router_] = true;

        isLimitExempt[msg.sender] = true;
        isLimitExempt[address(this)] = true;
        isLimitExempt[router_] = true;
        isLimitExempt[pair] = true;

        emit RouterAndPairSet(router_, pair);
        emit SetTax(taxBps_);
        emit SetTaxWallet(taxWallet_);
        emit SetMaxTxAmount(maxTxAmount);
        emit SetMaxDailyTxCount(maxDailyTxCount);
        emit SetSwapAndLiquify(swapAndLiquifyEnabled, swapThreshold);
    }

    function setTax(uint16 bps) external onlyOwner {
        require(bps <= 1000, "tax too high");
        taxBps = bps;
        emit SetTax(bps);
    }

    function setTaxWallet(address wallet) external onlyOwner {
        if (wallet == address(0)) revert ZeroAddress();
        taxWallet = wallet;
        emit SetTaxWallet(wallet);
    }

    function setFeeExempt(address account, bool exempt) external onlyOwner {
        isFeeExempt[account] = exempt;
        emit SetFeeExempt(account, exempt);
    }

    function setLimitExempt(address account, bool exempt) external onlyOwner {
        isLimitExempt[account] = exempt;
        emit SetLimitExempt(account, exempt);
    }

    function setMaxTxAmount(uint256 amount) external onlyOwner {
        require(amount > 0, "invalid maxTx");
        maxTxAmount = amount;
        emit SetMaxTxAmount(amount);
    }

    function setMaxDailyTxCount(uint32 count) external onlyOwner {
        require(count > 0, "invalid dailyCount");
        maxDailyTxCount = count;
        emit SetMaxDailyTxCount(count);
    }

    function setSwapAndLiquify(bool enabled, uint256 threshold) external onlyOwner {
        swapAndLiquifyEnabled = enabled;
        swapThreshold = threshold;
        emit SetSwapAndLiquify(enabled, threshold);
    }

    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit SetTradingEnabled(true);
    }

    function addLiquidityETH(uint256 tokenAmount, uint256 amountTokenMin, uint256 amountETHMin, uint256 deadlineSeconds)
        external
        payable
        onlyOwner
    {
        _transfer(msg.sender, address(this), tokenAmount);
        _approve(address(this), address(router), tokenAmount);
        router.addLiquidityETH{value: msg.value}(
            address(this),
            tokenAmount,
            amountTokenMin,
            amountETHMin,
            msg.sender,
            block.timestamp + deadlineSeconds
        );
    }

    function removeLiquidity(uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin, uint256 deadlineSeconds)
        external
        onlyOwner
    {
        IUniswapV2Pair(pair).approve(address(router), liquidity);
        router.removeLiquidityETH(
            address(this),
            liquidity,
            amountTokenMin,
            amountETHMin,
            msg.sender,
            block.timestamp + deadlineSeconds
        );
    }

    function _updateDaily(address account) internal {
        if (block.timestamp >= lastReset[account] + 1 days) {
            lastReset[account] = block.timestamp;
            dailyCount[account] = 0;
        }
        dailyCount[account] += 1;
        if (!isLimitExempt[account] && dailyCount[account] > maxDailyTxCount) {
            revert DailyTxLimitExceeded(account, maxDailyTxCount);
        }
    }

    function _update(address from, address to, uint256 value) internal override {
        // 仅对普通转账应用税费与限制（排除 mint/burn）
        if (from != address(0) && to != address(0)) {
            if (!tradingEnabled && !(isLimitExempt[from] || isLimitExempt[to])) {
                revert TradingNotEnabled();
            }

            if (!isLimitExempt[from] && value > maxTxAmount) {
                revert MaxTxExceeded(value, maxTxAmount);
            }

            _updateDaily(from);

            uint256 taxAmount = 0;
            if (taxBps > 0 && !(isFeeExempt[from] || isFeeExempt[to])) {
                taxAmount = (value * taxBps) / 10000;
            }

            uint256 sendAmount = value - taxAmount;

            if (taxAmount > 0) {
                super._update(from, address(this), taxAmount);
            }

            if (
                swapAndLiquifyEnabled &&
                !inSwap &&
                from != pair &&
                balanceOf(address(this)) >= swapThreshold
            ) {
                _swapAndLiquify(balanceOf(address(this)));
            }

            super._update(from, to, sendAmount);
        } else {
            super._update(from, to, value);
        }
    }

    function _swapAndLiquify(uint256 tokenBalance) internal {
        inSwap = true;
        uint256 half = tokenBalance / 2;
        uint256 otherHalf = tokenBalance - half;

        uint256 initialETH = address(this).balance;
        _swapTokensForETH(half);
        uint256 newETH = address(this).balance - initialETH;

        _addLiquidity(otherHalf, newETH);
        inSwap = false;
    }

    function _swapTokensForETH(uint256 tokenAmount) internal {
        _approve(address(this), address(router), tokenAmount);
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        _approve(address(this), address(router), tokenAmount);
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function withdrawTaxTokens(uint256 amount) external onlyOwner {
        _transfer(address(this), taxWallet, amount);
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        (bool ok, ) = taxWallet.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    receive() external payable {}
}
