// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/MemeToken.sol";

contract AddLiquidity is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address payable tokenAddr = payable(vm.envAddress("TOKEN_ADDRESS"));

        MemeToken token = MemeToken(tokenAddr);

        vm.startBroadcast(pk);
        // 示例：向 LP 添加 10_000_000 * 1e18 代币和 5 ETH
        uint256 tokenAmount = 10_000_000 * 1e18;
        uint256 ethAmount = 5 ether;
        // 将代币从拥有者转至合约并添加流动性，最小滑点与截止时间可按需调整
        token.addLiquidityETH{value: ethAmount}(tokenAmount, tokenAmount * 95 / 100, ethAmount * 95 / 100, 600);
        vm.stopBroadcast();
    }
}
