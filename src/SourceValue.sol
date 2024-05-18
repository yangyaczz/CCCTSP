// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

contract SourceValue is ReentrancyGuard {
    address public immutable router;
    address public immutable sourceValue;
    uint256 public orderId;

    uint64 public chainSelectorBaseSep = 10344971235874465080;
    address public wethBaseSep = 0x4200000000000000000000000000000000000006;
    address public routerBaseSep = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;

    uint64 public chainSelectorArbSep = 3478487238524512106;
    address public wethArbSep = 0xE591bf0A0CF924A0674d7792db046B23CEbF5f34;
    address public routerArbSep = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;

    uint64 public chainSelectorOpSep = 5224473277236331295;
    address public wethOpSep = 0x4200000000000000000000000000000000000006;
    address public routerOpSep = 0x114A20A10b43D4115e5aeef7345a1A71d2a60C57;

    struct Order {
        uint256 orderId;
        address owner;
        uint256 collateralAmount;
        uint64 destinationChainSelector;
        address destinationToken;
        uint256 leverage;
        bool isOver;
    }

    enum Operate {
        Create,
        Close,
        Increase,
        Decrease
    }

    uint256 public createCommand = 0;
    uint256 public closeCommand = 1;
    uint256 public increaseCommand = 2;
    uint256 public decreaseCommand = 3;

    mapping(address => uint256) deposits;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256) public frozens;

    event DepositCollateral(address indexed user, uint256 amount);
    event WithdrawCollateral(address indexed user, uint256 amount);

    event OrderCreated(
        uint256 indexed orderId,
        bytes32 messageId,
        address user,
        uint256 collateralAmount,
        uint64 destinationChainSelector,
        address destinationToken,
        uint256 leverage
    );

    event OrderClosed(uint256 indexed orderId, bytes32 messageId);

    constructor(address _router, address _sourceValue) {
        router = _router;
        sourceValue = _sourceValue;
    }

    function depositCollateral() external payable nonReentrant {
        require(msg.value > 0, "msgvalue error");
        deposits[msg.sender] += msg.value;
        emit DepositCollateral(msg.sender, msg.value);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        require(deposits[msg.sender] > 0 && deposits[msg.sender] >= amount, "deposits error");

        deposits[msg.sender] -= amount;
        SafeTransferLib.safeTransferETH(msg.sender, amount);

        emit WithdrawCollateral(msg.sender, amount);
    }

    function createOrder(
        uint256 collateralAmount,
        uint64 destinationChainSelector,
        address destinationToken,
        uint256 leverage
    ) external nonReentrant {
        require(deposits[msg.sender] >= collateralAmount && collateralAmount > 0, "collateralAmount error");
        require(leverage <= 3, "leverage error");

        deposits[msg.sender] -= collateralAmount;
        frozens[msg.sender] += collateralAmount;

        orderId += 1;
        orders[orderId] = Order({
            orderId: orderId,
            owner: msg.sender,
            collateralAmount: collateralAmount,
            destinationChainSelector: destinationChainSelector,
            destinationToken: destinationToken,
            leverage: leverage,
            isOver: false
        });

        bytes memory encodeData = abi.encode(orderId, msg.sender, collateralAmount, destinationToken, leverage);

        bytes memory ccipData = abi.encode(createCommand, encodeData);

        // call ccip
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(sourceValue),
            data: ccipData,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(router).getFee(destinationChainSelector, message);

        bytes32 messageId = IRouterClient(router).ccipSend{value: fee}(destinationChainSelector, message);

        emit OrderCreated(
            orderId, messageId, msg.sender, collateralAmount, destinationChainSelector, destinationToken, leverage
        );
    }

    function closeOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.owner == msg.sender, "owner error");
        require(order.isOver == false, "isOver error");

        order.isOver = true;

        bytes memory ccipData = abi.encodeWithSignature("closeOrderDis(uint256)", orderId);

        // call ccip
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(sourceValue),
            data: ccipData,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(router).getFee(order.destinationChainSelector, message);

        bytes32 messageId = IRouterClient(router).ccipSend{value: fee}(order.destinationChainSelector, message);

        emit OrderClosed(orderId, messageId);
    }

    // function increaseCollateralToOrder(uint orderId, uint addAmount) external {
    // }
    // function decreaseCollateralToOrder() external {
    // }

    receive() external payable {}
}
