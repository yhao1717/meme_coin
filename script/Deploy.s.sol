// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/MemeToken.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address taxWallet = vm.envAddress("TAX_WALLET");
        address router = vm.envOr("ROUTER", address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)); // UniswapV2

        vm.startBroadcast(pk);
        MemeToken token = new MemeToken(
            "SHIBX",
            "SHIBX",
            1_000_000_000_000 * 1e18,
            router,
            300,
            taxWallet
        );
        token.enableTrading();
        vm.stopBroadcast();
    }
}
