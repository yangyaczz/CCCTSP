// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {DestinationValue} from "../src/DistinationValue.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    DestinationValue dv;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        dv = new DestinationValue(address(1), address(1));
        vm.stopBroadcast();
    } // forge script script/DeploySC.s.sol:Deploy --rpc-url https://rpc-holesky.morphl2.io --broadcast
}
