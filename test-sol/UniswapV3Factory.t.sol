// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import 'forge-std/Test.sol';
import {IUniswapV3Factory} from 'core/interfaces/IUniswapV3Factory.sol';
import {UniswapV3Factory} from 'core/UniswapV3Factory.sol';
import {UniswapV3Pool} from 'core/UniswapV3Pool.sol';

library Fee {
    uint24 constant LOW = 500;
    uint24 constant MEDIUM = 3000;
    uint24 constant HIGH = 10000;
}

library TickSpacing {
    int24 constant LOW = 10;
    int24 constant MEDIUM = 60;
    int24 constant HIGH = 200;
}

library Create2 {
    function getAddress(
        address deployer,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal returns (address) {
        // TODO: assembly
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                deployer,
                                keccak256(constructorArgs),
                                keccak256(creationCode)
                            )
                        )
                    )
                )
            );
    }

    function getCodeAt(address target) internal returns (bytes memory code) {
        assembly {
            let size := extcodesize(target)
            code := mload(0x40)
            mstore(0x40, add(code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(code, size)
            extcodecopy(target, add(code, 0x20), 0, size)
        }
    }
}

contract FullMathTest is Test {
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pool
    );

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    address constant deployer = address(uint160(uint256(keccak256('deployer'))));
    address constant newDeployer = address(uint160(uint256(keccak256(' new deployer'))));

    address constant testAddress1 = 0x1000000000000000000000000000000000000000;
    address constant testAddress2 = 0x2000000000000000000000000000000000000000;

    UniswapV3Factory factory;

    function setUp() external {
        vm.prank(deployer);
        factory = new UniswapV3Factory();
    }

    function test_deployer() external {
        assertEq(factory.owner(), deployer);
    }

    function test_factoryCreationCodeSize() external {
        assertTrue(type(UniswapV3Factory).creationCode.length <= 24602); // TODO: lt
    }

    function test_factoryBytecodeSize() external {
        uint256 size;
        assembly {
            size := extcodesize(sload(factory.slot))
        }
        assertTrue(size <= 24535); // TODO: lt
    }

    function test_poolBytecodeSize() external {
        address pool = factory.createPool(testAddress1, testAddress2, Fee.MEDIUM);
        uint256 size;
        assembly {
            size := extcodesize(pool)
        }
        assertTrue(size <= 22142); // TODO: lt
    }

    function test_initialEnabledFeeAmounts() external {
        assertEq(factory.feeAmountTickSpacing(Fee.LOW), TickSpacing.LOW);
        // assertEq(factory.feeAmountTickSpacing(Fee.MEDIUM), TickSpacing.MEDIUM);
        // assertEq(factory.feeAmountTickSpacing(Fee.HIGH), TickSpacing.HIGH);
    }

    function createAndCheckPool(
        address tokenA,
        address tokenB,
        uint24 fee,
        int24 tick
    ) internal {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes memory constructorArgs = abi.encode(token0, token1, fee);
        address futurePoolAddress =
            Create2.getAddress(address(factory), type(UniswapV3Pool).creationCode, constructorArgs);

        vm.expectEmit(true, true, true, true, address(factory));
        emit PoolCreated(token0, token1, fee, tick, futurePoolAddress);
        address poolAddress = factory.createPool(tokenA, tokenB, fee);
        assertEq(futurePoolAddress, poolAddress);

        vm.expectRevert();
        factory.createPool(tokenA, tokenB, fee);
        vm.expectRevert();
        factory.createPool(tokenB, tokenA, fee);

        assertEq(factory.getPool(tokenA, tokenB, fee), futurePoolAddress);
        assertEq(factory.getPool(tokenB, tokenA, fee), futurePoolAddress);

        UniswapV3Pool pool = UniswapV3Pool(poolAddress);
        assertEq(pool.factory(), address(factory));
        assertEq(pool.token0(), token0);
        assertEq(pool.token1(), token1);
        assertEq(uint256(pool.fee()), uint256(fee));
        assertEq(pool.tickSpacing(), tick);
    }

    // 22424
    function test_createPool_fees() external {
        createAndCheckPool(testAddress1, testAddress2, Fee.LOW, TickSpacing.LOW);
        createAndCheckPool(testAddress1, testAddress2, Fee.MEDIUM, TickSpacing.MEDIUM);
        createAndCheckPool(testAddress1, testAddress2, Fee.HIGH, TickSpacing.HIGH);
    }

    function test_createPool_reverse() external {
        createAndCheckPool(testAddress2, testAddress1, Fee.MEDIUM, TickSpacing.MEDIUM);
    }

    function test_createPool_sameToken() external {
        vm.expectRevert();
        factory.createPool(testAddress1, testAddress1, Fee.LOW);
    }

    function test_createPool_addressZero() external {
        vm.expectRevert();
        factory.createPool(testAddress1, address(0), Fee.LOW);
        vm.expectRevert();
        factory.createPool(address(0), testAddress1, Fee.LOW);
        vm.expectRevert();
        factory.createPool(address(0), address(0), Fee.LOW);
    }

    function test_createPool_feeAmountNotEnabled() external {
        vm.expectRevert();
        factory.createPool(testAddress1, testAddress2, 250);
    }

    function test_createPool_fuzz(address tokenA, address tokenB) external {
        vm.assume(tokenA != address(0) && tokenA != tokenB && tokenB != address(0));
        createAndCheckPool(tokenA, tokenB, Fee.LOW, TickSpacing.LOW);
        createAndCheckPool(tokenA, tokenB, Fee.MEDIUM, TickSpacing.MEDIUM);
        createAndCheckPool(tokenA, tokenB, Fee.HIGH, TickSpacing.HIGH);
    }

    function test_setOwner() external {
        vm.prank(address(1));
        vm.expectRevert();
        factory.setOwner(address(1));

        vm.prank(deployer);
        factory.setOwner(newDeployer);
        assertEq(newDeployer, factory.owner());

        vm.prank(deployer);
        vm.expectRevert();
        factory.setOwner(deployer);

        vm.expectEmit(true, true, true, true, address(factory));
        emit OwnerChanged(newDeployer, deployer);
        vm.prank(newDeployer);
        factory.setOwner(deployer);
    }

    function test_enableFeeAmount_notOwner() external {
        // fails if caller is not owner
        vm.prank(address(1));
        vm.expectRevert();
        factory.enableFeeAmount(100, 2);
    }

    function test_enableFeeAmount_feeTooGreat() external {
        vm.prank(deployer);
        vm.expectRevert();
        factory.enableFeeAmount(1000000, 2);
    }

    function test_enableFeeAmount_tickSpacingTooSmall() external {
        vm.prank(deployer);
        vm.expectRevert();
        factory.enableFeeAmount(500, 0);
    }

    function test_enableFeeAmount_tickSpacingTooLarge() external {
        vm.prank(deployer);
        vm.expectRevert();
        factory.enableFeeAmount(500, 16834);
    }

    function test_enableFeeAmount_alreadyInitialized() external {
        vm.startPrank(deployer);
        factory.enableFeeAmount(100, 5);
        vm.expectRevert();
        factory.enableFeeAmount(100, 5);
    }

    function test_enableFeeAmount_setsTickInMapping() external {
        vm.prank(deployer);
        factory.enableFeeAmount(100, 5);
        assertEq(factory.feeAmountTickSpacing(100), 5);
    }

    function test_enableFeeAmount_emitsEvent() external {
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true, address(factory));
        emit FeeAmountEnabled(100, 5);
        factory.enableFeeAmount(100, 5);
    }

    function test_enableFeeAmount_enablesPoolCreation() external {
        vm.prank(deployer);
        factory.enableFeeAmount(250, 15);
        createAndCheckPool(testAddress1, testAddress2, 250, 15);
    }
}
