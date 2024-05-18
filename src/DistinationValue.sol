// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IUniswapV2Router} from "./interfaces/univ2router.sol";

contract DestinationMinter is CCIPReceiver {
    IUniswapV2Router public univ2Router;

    constructor(address router, address _univ2Router) CCIPReceiver(router) {
        univ2Router = IUniswapV2Router(_univ2Router);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // decode message
        (
            uint256 command,
            uint256 orderId,
            address owner,
            uint256 collateralAmount,
            address destinationToken,
            uint256 leverage
        ) = abi.decode(message.data, (uint256, uint256, address, uint256, address, uint256));

        // swap in pool and get token

        if (command == 1) {
            createOrder(message.data);
        }
    }

    function createOrder(bytes memory data) internal {
        (
            uint256 command,
            uint256 orderId,
            address owner,
            uint256 collateralAmount,
            address destinationToken,
            uint256 leverage
        ) = abi.decode(data, (uint256, uint256, address, uint256, address, uint256));

        address[] memory path = new address[](2);
        path[0] = univ2Router.WETH();
        path[1] = destinationToken;

        uint256[] memory amounts = univ2Router.swapExactETHForTokens{value: collateralAmount * leverage}(
            0, path, address(this), block.timestamp
        );
        uint256 amount0 = amounts[0];
    }
}
