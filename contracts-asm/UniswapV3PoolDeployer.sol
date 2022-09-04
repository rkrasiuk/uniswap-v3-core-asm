// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IUniswapV3PoolDeployer.sol';

import './UniswapV3Pool.sol';

contract UniswapV3PoolDeployer is IUniswapV3PoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    /// @inheritdoc IUniswapV3PoolDeployer
    Parameters public override parameters;

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        bytes memory bytecode = type(UniswapV3Pool).creationCode;
        assembly {
            sstore(0, factory)
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
        }
    }
}
