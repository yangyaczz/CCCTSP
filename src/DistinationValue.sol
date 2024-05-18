// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IUniswapV2Router} from "./interfaces/univ2router.sol";

contract DestinationValue is CCIPReceiver {
    IUniswapV2Router public univ2Router;

    uint256 public liqudityLine = 800; // 800 / 1000 = 80%

    struct DistinationOrder {
        uint256 orderId;
        address owner;
        uint256 collateralAmount;
        uint256 leverage;
        address destinationToken;
        uint256 swapAssetAmount;
        bool isOver;
    }

    mapping(uint256 => DistinationOrder) public distinationOrders;

    constructor(address router, address _univ2Router) CCIPReceiver(router) {
        univ2Router = IUniswapV2Router(_univ2Router);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // decode message
        (uint256 command, bytes memory data) = abi.decode(message.data, (uint256, bytes));

        if (command == 0) {
            createOrder(data);
        } else if (command == 1) {
            closeOrder(data);
        }
    }

    function closeOrder(bytes memory data) internal {}

    function createOrder(bytes memory data) internal {
        (uint256 orderId, address owner, uint256 collateralAmount, address destinationToken, uint256 leverage) =
            abi.decode(data, (uint256, address, uint256, address, uint256));

        address[] memory path = new address[](2);
        path[0] = univ2Router.WETH();
        path[1] = destinationToken;

        uint256[] memory amounts = univ2Router.swapExactETHForTokens{value: collateralAmount * leverage}(
            0, path, address(this), block.timestamp
        );
        uint256 amount1 = amounts[1];

        distinationOrders[orderId] = DistinationOrder({
            orderId: orderId,
            owner: owner,
            collateralAmount: collateralAmount,
            leverage: leverage,
            destinationToken: destinationToken,
            swapAssetAmount: amount1,
            isOver: false
        });
    }

    function liquidity(uint256 orderId) external {
        DistinationOrder storage order = distinationOrders[orderId];

        address[] memory path = new address[](2);
        path[0] = order.destinationToken;
        path[1] = univ2Router.WETH();

        uint256[] memory amounts =
            univ2Router.swapExactTokensForETH(order.swapAssetAmount, 0, path, address(this), block.timestamp);

        require(amounts[1] <= order.collateralAmount * liqudityLine / 1000, "can't liquidity");
    }
}
