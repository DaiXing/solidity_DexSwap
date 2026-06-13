// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/ISwapRouter.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolManager.sol";

contract SwapRouter is ISwapRouter {
    IPoolManager poolManager;

    constructor(address poolManager_) {
        poolManager = IPoolManager(poolManager_);
    }

    // 指定输入的币。 返回输出的币。
    function exactInput(
        ExactInputParams calldata params
    ) external returns (uint256 amountOut) {
        uint256 amountIn = params.amountIn;
        bool zeroForOne = params.tokenIn < params.tokenOut;

        // 指定了多个池子。
        uint256 poolIndexCount = params.indexPath.length;
        for (uint256 m = 0; m < poolIndexCount; m++) {
            uint32 poolIndex = params.indexPath[m];

            // 池子。
            address poolAddr = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                poolIndex
            );
            require(poolAddr != address(0), "pool not found");
            IPool pool = IPool(poolAddr);

            // 回调。
            bytes memory data = abi.encode(
                params.tokenIn,
                params.tokenOut,
                poolIndex,
                params.recipient == address(0) ? address(0) : msg.sender
            );

            // 交换。
            (int256 amount0, int256 amount1) = swapInPool(
                pool,
                params.recipient,
                zeroForOne,
                int256(amountIn),
                params.sqrtPriceLimitX96,
                data
            );

            // 数量变化了。
            amountIn -= uint256(zeroForOne ? amount0 : amount1);
            amountOut += uint256(zeroForOne ? -amount1 : -amount0);

            // 处理完了。
            if (amountIn == 0) {
                break;
            }
        }

        // 数量不满足。
        require(amountOut >= params.amountOutMinimum, "amountOut not enough");

        emit Swap(msg.sender, zeroForOne, params.amountIn, amountIn, amountOut);
    }

    // 指定输出的币。 返回输入的币。
    function exactOutput(
        ExactOutputParams calldata params
    ) external returns (uint256 amountIn) {
        uint256 amountOut = params.amountOut;
        bool zeroForOne = params.tokenIn < params.tokenOut;

        // 指定了多个池子。
        uint256 poolIndexCount = params.indexPath.length;
        for (uint256 m = 0; m < poolIndexCount; m++) {
            uint32 poolIndex = params.indexPath[m];

            // 池子。
            address poolAddr = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                poolIndex
            );
            require(poolAddr != address(0), "pool not found");
            IPool pool = IPool(poolAddr);

            // 回调。
            bytes memory data = abi.encode(
                params.tokenIn,
                params.tokenOut,
                poolIndex,
                params.recipient == address(0) ? address(0) : msg.sender
            );

            // 交换。
            (int256 amount0, int256 amount1) = swapInPool(
                pool,
                recipient,
                zeroForOne,
                -int256(amountOut),
                params.sqrtPriceLimitX96,
                data
            );

            // 数量变化了。
            amountIn += uint256(zeroForOne ? amount0 : amount1);
            amountOut -= uint256(zeroForOne ? -amount1 : -amount0);

            // 处理完了。
            if (amountOut == 0) {
                break;
            }
        }

        // 花费太多了。
        require(amountIn <= params.amountInMaximum, "amountIn too much");

        emit Swap(
            msg.sender,
            zeroForOne,
            params.amountOut,
            amountOut,
            amountIn
        );
    }

    // 报价。指定输入的币。 返回输出的币。
    function quoteExactInput(
        QuoteExactInputParams calldata data
    ) external returns (uint256 amountOut) {
        amountOut = exactInput(
            ExactInputParams({
                tokenIn: data.tokenIn,
                tokenOut: data.tokenOut,
                indexPath: data.indexPath,
                amountIn: data.amountIn,
                amountOutMinimum: 0,
                recipient: address(0),
                deadline: block.timestamp + 1 hours,
                sqrtPriceLimitX96: data.sqrtPriceLimitX96
            })
        );
    }

    // 报价。指定输出的币。 返回输入的币。
    function quoteExactOutput(
        QuoteExactOutputParams calldata params
    ) external returns (uint256 amountIn) {
        amountIn = exactOutput(
            ExactOutputParams({
                tokenIn: data.tokenIn,
                tokenOut: data.tokenOut,
                indexPath: data.indexPath,
                amountOut: data.amountOut,
                amountInMaximum: type(uint256).max,
                recipient: address(0),
                deadline: block.timestamp + 1 hours,
                sqrtPriceLimitX96: data.sqrtPriceLimitX96
            })
        );
    }

    // 交换的回调
    function swapCallback(
        uint256 amount0Delta, // 币0的数量。变化量
        uint256 amount1Delta, // 币1的数量。变化量
        bytes calldata data // 数据
    ) external {
        // 解码。
        (address tokenIn, address tokenOut, uint32 index, address payer) = abi
            .decode(data, (address, address, uint32, address));

        // 池子
        address poolAddr = poolManager.getPool(tokenIn, tokenOut, index);
        IPool pool = IPool(poolAddr);

        // 池子调过来的。
        require(poolAddr == msg.sender, "caller is not pool");

        // payer 是 address(0)，这是一个用于预估 token 的请求（quoteExactInput or quoteExactOutput）
        if (payer == address(0)) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amount0Delta)
                mstore(add(ptr, 0x20), amount1Delta)
                revert(ptr, 64)
            }
        }

        // 需要支付。
        uint256 amountToPay = amount0Delta > 0 ? amount0Delta : amount1Delta;

        // 转账。给池子。
        if (amountToPay > 0) {
            IERC20(tokenIn).transferFrom(payer, poolAddr, amountToPay);
        }
    }

    function parseRevertReason(
        bytes memory reason
    ) private pure returns (uint256, uint256) {
        if (reason.length != 64) {
            if (reason.length < 68) {
                revert("Unknown error");
            }
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        abi.decode(reason, (uint256, uint256));
    }

    // 在某个池子，交易。 包装异常。
    function swapInPool(
        IPool pool,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        try
            pool.swap(
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                tick
            )
        returns (int256 amount0_, int256 amount1_) {
            return (amount0_, amount1_);
        } catch (bytes memory reason) {
            parseRevertReason(reason);
        }
    }
}
