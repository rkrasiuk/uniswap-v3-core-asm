// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IUniswapV3Factory.sol';

import './UniswapV3PoolDeployer.sol';
import './NoDelegateCall.sol';

import './UniswapV3Pool.sol';

/// @title Canonical Uniswap V3 factory
/// @notice Deploys Uniswap V3 pools and manages ownership and control over pool protocol fees
contract UniswapV3Factory is IUniswapV3Factory, UniswapV3PoolDeployer, NoDelegateCall {
    /// @inheritdoc IUniswapV3Factory
    address public override owner;

    /// @inheritdoc IUniswapV3Factory
    mapping(uint24 => int24) public override feeAmountTickSpacing;
    /// @inheritdoc IUniswapV3Factory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    constructor() {
        assembly {
            sstore(owner.slot, caller())
            log3(0, 0, 0xb532073b38c83145e3e5135377a08bf9aab55bc0fd7c1179cd4fb995d2a5159c, 0, caller())

            mstore(32, feeAmountTickSpacing.slot)

            mstore(0, 500)
            sstore(keccak256(0, 64), 10)
            log3(0, 0, 0xc66a3fdf07232cdd185febcc6579d408c241b47ae2f9907d84be655141eeaecc, 0, 500)

            mstore(0, 3000)
            sstore(keccak256(0, 64), 60)
            log3(0, 0, 0xc66a3fdf07232cdd185febcc6579d408c241b47ae2f9907d84be655141eeaecc, 3000, 60)

            mstore(0, 10000)
            sstore(keccak256(0, 64), 200)
            log3(0, 0, 0xc66a3fdf07232cdd185febcc6579d408c241b47ae2f9907d84be655141eeaecc, 10000, 200)
        }
    }

    /// @inheritdoc IUniswapV3Factory
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override noDelegateCall returns (address pool) {
        address token0;
        address token1;
        int24 tickSpacing;
        bytes32 storageLocation;
        assembly {
            if eq(tokenA, tokenB) {
                revert(0, 0)
            }

            switch lt(tokenA, tokenB)
                case 1 {
                    token0 := tokenA
                    token1 := tokenB
                }
                default {
                    token0 := tokenB
                    token1 := tokenA
                }

            if iszero(token0) {
                // mload(128)) {
                revert(0, 0)
            }

            mstore(0, fee)
            mstore(32, feeAmountTickSpacing.slot)
            tickSpacing := sload(keccak256(0, 64))
            if iszero(tickSpacing) {
                revert(0, 0)
            }

            // compute storage location
            mstore(0, token0)
            mstore(32, getPool.slot)
            let firstHash := keccak256(0, 64)
            mstore(0, token1)
            mstore(32, firstHash)
            let secondHash := keccak256(0, 64)
            mstore(0, fee)
            mstore(32, secondHash)
            storageLocation := keccak256(0, 64)
            let existing := sload(storageLocation)
            if eq(iszero(existing), 0) {
                revert(0, 0)
            }
        }

        // pool = deploy(address(this), token0, token1, fee, tickSpacing);
        bytes memory bytecode = type(UniswapV3Pool).creationCode;
        assembly {
            // deploy start
            sstore(0, address())
            sstore(1, token0)
            sstore(2, or(or(token1, shl(160, fee)), shl(184, tickSpacing)))

            let ptr := mload(0x40)
            mstore(add(ptr, 32), token0)
            mstore(add(ptr, 64), token1)
            mstore(add(ptr, 96), fee)
            pool := create2(0, add(bytecode, 32), mload(bytecode), keccak256(add(ptr, 32), 96))
            sstore(0, 0)
            sstore(1, 0)
            sstore(2, 0)
            // deploy end

            sstore(storageLocation, pool)

            // compute reverse storage location
            mstore(0, token1)
            mstore(32, getPool.slot)
            let firstHash := keccak256(0, 64)
            mstore(0, token0)
            mstore(32, firstHash)
            let secondHash := keccak256(0, 64)
            mstore(0, fee)
            mstore(32, secondHash)
            sstore(keccak256(0, 64), pool)

            mstore(0, tickSpacing)
            mstore(32, pool)
            log4(0, 64, 0x783cca1c0412dd0d695e784568c96da2e9c22ff989357a2e8b1d9b2b4e6b7118, token0, token1, fee)
        }
    }

    /// @inheritdoc IUniswapV3Factory
    function setOwner(address _owner) external override {
        assembly {
            if eq(eq(caller(), sload(owner.slot)), 0) {
                revert(0, 0)
            }
            log3(0, 0, 0xb532073b38c83145e3e5135377a08bf9aab55bc0fd7c1179cd4fb995d2a5159c, caller(), _owner)
            sstore(owner.slot, _owner)
        }
    }

    /// @inheritdoc IUniswapV3Factory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        assembly {
            if eq(eq(caller(), sload(owner.slot)), 0) {
                revert(0, 0)
            }
            if gt(fee, 999999) {
                revert(0, 0)
            }

            // tick spacing is capped at 16384 to prevent the situation where tickSpacing is so large that
            // TickBitmap#nextInitializedTickWithinOneWord overflows int24 container from a valid tick
            // 16384 ticks represents a >5x price change with ticks of 1 bips
            if or(lt(tickSpacing, 1), gt(tickSpacing, 16383)) {
                revert(0, 0)
            }

            mstore(0, fee)
            mstore(32, feeAmountTickSpacing.slot)
            let storageLocation := keccak256(0, 64)
            if eq(iszero(sload(storageLocation)), 0) {
                revert(0, 0)
            }

            sstore(storageLocation, tickSpacing)
            log3(0, 0, 0xc66a3fdf07232cdd185febcc6579d408c241b47ae2f9907d84be655141eeaecc, fee, tickSpacing)
        }
    }
}
