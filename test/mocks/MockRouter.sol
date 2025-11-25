// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/interfaces/IUniswapV2Router02.sol";

contract MockRouter is IUniswapV2Router02 {
    address private _factory;
    address private _weth;

    constructor(address factory_, address weth_) {
        _factory = factory_;
        _weth = weth_;
    }

    function factory() external view override returns (address) {
        return _factory;
    }

    function WETH() external view override returns (address) {
        return _weth;
    }

    function addLiquidityETH(
        address /*token*/,
        uint /*amountTokenDesired*/,
        uint /*amountTokenMin*/,
        uint /*amountETHMin*/,
        address /*to*/,
        uint /*deadline*/
    ) external payable override returns (uint amountToken, uint amountETH, uint liquidity) {
        return (0, 0, 0);
    }

    function removeLiquidityETH(
        address /*token*/,
        uint /*liquidity*/,
        uint /*amountTokenMin*/,
        uint /*amountETHMin*/,
        address /*to*/,
        uint /*deadline*/
    ) external override returns (uint amountToken, uint amountETH) {
        return (0, 0);
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint /*amountIn*/,
        uint /*amountOutMin*/,
        address[] calldata /*path*/,
        address /*to*/,
        uint /*deadline*/
    ) external override {}

    function getAmountsOut(uint amountIn, address[] calldata /*path*/) external view override returns (uint[] memory amounts) {
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }
}

