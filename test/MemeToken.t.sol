// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/MemeToken.sol";
import "test/mocks/MockRouter.sol";
import "test/mocks/MockFactory.sol";

contract MemeTokenTest is Test {
    address owner = address(0xABCD);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    MemeToken token;

    // 测试用 Mock 路由/工厂
    address weth = address(0xBEEF);

    function setUp() public {
        vm.startPrank(owner);
        MockFactory factory = new MockFactory();
        MockRouter router = new MockRouter(address(factory), weth);
        token = new MemeToken(
            "SHIBX",
            "SHIBX",
            1_000_000 * 1e18,
            address(router),
            500, // 5%
            owner
        );
        token.setSwapAndLiquify(false, type(uint256).max); // 关闭自动回流，避免与外部路由交互
        token.enableTrading();
        vm.stopPrank();

        // 分配初始代币给 Alice
        vm.prank(owner);
        token.transfer(alice, 100_000 * 1e18);
    }

    function testTaxOnTransfer() public {
        // Alice 转给 Bob 10_000 代币，税率 5% => 税 500
        vm.prank(alice);
        token.transfer(bob, 10_000 * 1e18);

        assertEq(token.balanceOf(bob), 9_500 * 1e18);
        assertEq(token.balanceOf(address(token)), 500 * 1e18); // 税留在合约中
    }

    function testMaxTxLimit() public {
        // 将单笔最大交易额设置为 1_000 * 1e18
        vm.prank(owner);
        token.setMaxTxAmount(1_000 * 1e18);

        vm.startPrank(alice);
        vm.expectRevert();
        token.transfer(bob, 5_000 * 1e18);
        vm.stopPrank();
    }

    function testDailyTxCountLimit() public {
        vm.prank(owner);
        token.setMaxDailyTxCount(2);

        vm.startPrank(alice);
        token.transfer(bob, 100 * 1e18);
        token.transfer(bob, 100 * 1e18);
        vm.expectRevert();
        token.transfer(bob, 100 * 1e18); // 第三次超限
        vm.stopPrank();
    }
}
