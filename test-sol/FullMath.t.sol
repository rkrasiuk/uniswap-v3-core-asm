// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import 'forge-std/Test.sol';
import {FullMath} from 'core/libraries/FullMath.sol';

contract FullMathTest is Test {
    uint256 constant Q128 = 2**128;
    uint256 constant MAX = type(uint256).max;

    function test_mulDiv_reverts() external {
        // denominator zero
        vm.expectRevert();
        FullMath.mulDiv(Q128, 5, 0);

        // denominator zero and numerator overflow
        vm.expectRevert();
        FullMath.mulDiv(Q128, Q128, 0);

        // output overflows uint256
        vm.expectRevert();
        FullMath.mulDiv(Q128, Q128, 1);
        vm.expectRevert();
        FullMath.mulDiv(MAX, MAX, MAX - 1);
    }

    function test_mulDiv_allMaxInputs() external {
        assertEq(FullMath.mulDiv(MAX, MAX, MAX), MAX);
    }

    function test_mulDiv_accuratePhantomOverflow() external {
        // without phantom overflow
        assertEq(FullMath.mulDiv(Q128, (50 * Q128) / 100, (150 * Q128) / 100), Q128 / 3);

        // with phantom overflow
        assertEq(FullMath.mulDiv(Q128, 35 * Q128, 8 * Q128), (4375 * Q128) / 1000);

        // with phantom overflow and repeating decimals
        assertEq(FullMath.mulDiv(Q128, 1000 * Q128, 3000 * Q128), Q128 / 3);
    }

    function test_mulDivRoundingUp_reverts() external {
        // denominator zero
        vm.expectRevert();
        FullMath.mulDivRoundingUp(Q128, 5, 0);

        // denominator zero and numerator overflows
        vm.expectRevert();
        FullMath.mulDivRoundingUp(Q128, Q128, 0);

        // output overflows uint256
        vm.expectRevert();
        FullMath.mulDivRoundingUp(Q128, Q128, 1);
        vm.expectRevert();
        FullMath.mulDivRoundingUp(MAX, MAX, MAX - 1);

        // result overflows 256 bits after rounding up
        vm.expectRevert();
        FullMath.mulDivRoundingUp(535006138814359, 432862656469423142931042426214547535783388063929571229938474969, 2);
        vm.expectRevert();
        FullMath.mulDivRoundingUp(
            115792089237316195423570985008687907853269984659341747863450311749907997002549,
            115792089237316195423570985008687907853269984659341747863450311749907997002550,
            115792089237316195423570985008687907853269984653042931687443039491902864365164
        );
    }

    function test_mulDivRoundingUp_accuratePhantomOverflow() external {
        // without phantom overflow
        assertEq(FullMath.mulDivRoundingUp(Q128, (50 * Q128) / 100, (150 * Q128) / 100), Q128 / 3 + 1);

        // with phantom overflow
        assertEq(FullMath.mulDivRoundingUp(Q128, 35 * Q128, 8 * Q128), (4375 * Q128) / 1000);

        // with phantom overflow and repeating decimals
        assertEq(FullMath.mulDivRoundingUp(Q128, 1000 * Q128, 3000 * Q128), Q128 / 3 + 1);
    }

    // light fuzz
    // result is checked in all cases where a * b <= type(uint256).max
    function test_mulDiv_and_mulDivRoundingUp_fuzz(
        uint256 a,
        uint256 b,
        uint256 denom
    ) external {
        bool valid;
        assembly {
            let mm := mulmod(a, b, not(0))
            let prod0 := mul(a, b)
            let prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            valid := or(and(iszero(prod1), not(iszero(denom))), gt(denom, prod1))
        }
        if (valid) {
            uint256 rawResult = (a * b) / denom;

            // expect not to revert
            uint256 result = FullMath.mulDiv(a, b, denom);
            // check if we can validate the result
            if ((rawResult * denom) / (b == 0 ? 1 : b) == a) {
                assertEq(result, rawResult);

                uint256 roundResult = FullMath.mulDivRoundingUp(a, b, denom);
                if (result < type(uint256).max) {
                    assertEq(roundResult, rawResult + (((a * b) % denom) > 0 ? 1 : 0));
                }
            }
        } else {
            vm.expectRevert();
            FullMath.mulDiv(a, b, denom);
            vm.expectRevert();
            FullMath.mulDivRoundingUp(a, b, denom);
        }
    }
}
