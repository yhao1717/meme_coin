// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/interfaces/IUniswapV2Pair.sol";

contract MockPair is IUniswapV2Pair {
    address public override token0;
    address public override token1;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function balanceOf(address owner) external view override returns (uint) {
        return _balances[owner];
    }

    function approve(address spender, uint value) external override returns (bool) {
        _allowances[msg.sender][spender] = value;
        return true;
    }
}

