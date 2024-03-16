// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/types/PoolId.sol";
import {Constants} from "@uniswap/v4-core/contracts/../test/utils/Constants.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/types/Currency.sol";
import {HookTest} from "./utils/HookTest.sol";
import {NoSwap} from "../src/NoSwap.sol";
import {HookMiner} from "./utils/HookMiner.sol";

contract NoSwapTest is HookTest {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    NoSwap hook;
    PoolKey poolKey;
    PoolId poolId;

    function setUp() public {
        // creates the pool manager, test tokens, and other utility routers
        HookTest.initHookTestEnv();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.NO_OP_FLAG | Hooks.ACCESS_LOCK_FLAG
        );
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(NoSwap).creationCode,
            abi.encode(address(manager))
        );
        hook = new NoSwap{salt: salt}(IPoolManager(address(manager)));
        require(
            address(hook) == hookAddress,
            "CounterTest: hook address mismatch"
        );

        // Create the pool
        poolKey = PoolKey(
            Currency.wrap(address(token0)),
            Currency.wrap(address(token1)),
            3000,
            60,
            IHooks(hook)
        );
        poolId = poolKey.toId();
        initializeRouter.initialize(
            poolKey,
            Constants.SQRT_RATIO_1_1,
            ZERO_BYTES
        );

        // Provide liquidity to the pair, so there are tokens that we can take
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(-60, 60, 100000 ether),
            ZERO_BYTES
        );

        // Provide liquidity to the hook, so there are tokens on the constant sum curve
        token0.approve(address(hook), type(uint256).max);
        token1.approve(address(hook), type(uint256).max);
    }

    function test_csmm_gas() public {
        int256 amount = 1e18;
        bool zeroForOne = true;
        uint256 gasBefore = gasleft();
        swap(poolKey, amount, zeroForOne, ZERO_BYTES);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        console2.log("csmm gas used: ", gasUsed);
    }

    function test_multiswap_gas() public {
        swapTokenWithLog();
        swapTokenWithLog();
        swapTokenWithLog();
        swapTokenWithLog();
    }

    function test_Odd() public {
        hook.setOdd(true);
        swapTokenWithLog();
    }

    function test_Even() public {
        hook.setOdd(false);
        swapTokenWithLog();
    }

    function swapTokenWithLog() internal {
        int256 amount = 1e18;
        bool zeroForOne = true;
        uint256 gasBefore = gasleft();
        swap(poolKey, amount, zeroForOne, ZERO_BYTES);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        console2.log("swap gas used: ", gasUsed);
    }
}
