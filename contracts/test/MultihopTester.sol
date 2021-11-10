// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {SafeCast} from '../libraries/SafeCast.sol';
import {TickMath} from '../libraries/TickMath.sol';

import {IERC20Minimal} from '../interfaces/external/IERC20Minimal.sol';
import {ISwapCallback} from '../interfaces/callback/ISwapCallback.sol';
import {IPool} from '../interfaces/IPool.sol';

contract MultihopTester is ISwapCallback {
    using SafeCast for uint256;

    // flash swaps for an exact amount of token0 in the output pool
    function swapForExact0Multi(
        address recipient,
        address poolInput,
        address poolOutput,
        uint256 amount0Out
    ) external {
        address[] memory pools = new address[](1);
        pools[0] = poolInput;
        IPool(poolOutput).swap(
            recipient,
            false,
            -amount0Out.toInt256(),
            TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(pools, msg.sender)
        );
    }

    // flash swaps for an exact amount of token1 in the output pool
    function swapForExact1Multi(
        address recipient,
        address poolInput,
        address poolOutput,
        uint256 amount1Out
    ) external {
        address[] memory pools = new address[](1);
        pools[0] = poolInput;
        IPool(poolOutput).swap(
            recipient,
            true,
            -amount1Out.toInt256(),
            TickMath.MIN_SQRT_RATIO + 1,
            abi.encode(pools, msg.sender)
        );
    }

    event ISwapCallback(int256 amount0Delta, int256 amount1Delta);

    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        emit ISwapCallback(amount0Delta, amount1Delta);

        (address[] memory pools, address payer) = abi.decode(data, (address[], address));

        if (pools.length == 1) {
            // get the address and amount of the token that we need to pay
            address tokenToBePaid = amount0Delta > 0 ? IPool(msg.sender).token0() : IPool(msg.sender).token1();
            int256 amountToBePaid = amount0Delta > 0 ? amount0Delta : amount1Delta;

            bool zeroForOne = tokenToBePaid == IPool(pools[0]).token1();
            IPool(pools[0]).swap(
                msg.sender,
                zeroForOne,
                -amountToBePaid,
                zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                abi.encode(new address[](0), payer)
            );
        } else {
            if (amount0Delta > 0) {
                IERC20Minimal(IPool(msg.sender).token0()).transferFrom(payer, msg.sender, uint256(amount0Delta));
            } else {
                IERC20Minimal(IPool(msg.sender).token1()).transferFrom(payer, msg.sender, uint256(amount1Delta));
            }
        }
    }
}