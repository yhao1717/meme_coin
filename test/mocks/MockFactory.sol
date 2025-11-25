// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/interfaces/IUniswapV2Factory.sol";
import "test/mocks/MockPair.sol";

contract MockFactory is IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        pair = address(new MockPair(tokenA, tokenB));
    }
}

