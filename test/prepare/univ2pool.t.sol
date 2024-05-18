// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "../../src/tests/MockERC20.sol";
import {CPAMM} from "../../src/tests/CPAMM.sol";
import {WETH} from "solmate/tokens/WETH.sol";

contract Univ2Prepare is Test {
    MockERC20 public tk;
    CPAMM public cpamm;

    address alice = 0xBEbAF2a9ad714fEb9Dd151d81Dd6d61Ae0535646;

    WETH weth = WETH(payable(0xE591bf0A0CF924A0674d7792db046B23CEbF5f34));

    function setUp() public {
        tk = new MockERC20("fake-gmx", "fake-gmx");
        cpamm = new CPAMM(address(tk), address(weth));

        console2.log(alice.balance);
    }

    function testAddLiqudity() public {
        vm.startPrank(alice);

        uint256 amount0 = 0.1 ether;
        uint256 amount1 = 0.1 ether;

        weth.deposit{value: amount0}();
        tk.mint(amount1);

        weth.approve(address(cpamm), type(uint256).max);
        tk.approve(address(cpamm), type(uint256).max);

        cpamm.addLiquidity(amount0, amount1);
    }
} // forge test --match-path test/prepare/univ2pool.t.sol --fork-url https://arbitrum-sepolia.blockpi.network/v1/rpc/public  --fork-block-number 45455200 -vv
