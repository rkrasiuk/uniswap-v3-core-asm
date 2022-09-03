// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import 'forge-std/Test.sol';
import {BitMath} from 'core/libraries/BitMath.sol';

contract BitMathTest is Test {
    function test_mostSignificantBit_zero() external {
        vm.expectRevert();
        BitMath.mostSignificantBit(0);
    }

    function test_mostSignificantBit_fuzz(uint8 num) external {
        assertEq(uint256(BitMath.mostSignificantBit(2**num)), num);
    }

    function test_leastSignificantBit_zero() external {
        vm.expectRevert();
        BitMath.leastSignificantBit(0);
    }

    function test_leastSignificantBit_fuzz(uint8 num) external {
        assertEq(uint256(BitMath.leastSignificantBit(2**num)), num);
    }
}
