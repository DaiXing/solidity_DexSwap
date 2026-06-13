// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./IPool.sol";

// 交换。交易。路由。
interface ISwapRouter is ISwapCallback {
    // 交换
    event Swap(
        address indexed sender,
        bool zeroForOne, // 用token0换token1
        uint256 amountIn, // 输入的数量
        uint256 amountInRemaining, // 输入的剩余数量
        uint256 amountOut // 输出的数量
    );

    // 指定输入的币。
    struct ExactInputParams {
        address tokenIn; // 输入的币
        address tokenOut; // 输出的币
        uint32[] indexPath; // 池子下标。
        address recipient; // 归属人。
        uint256 deadline; // 截止时间
        uint256 amountIn; // 输入的数量
        uint256 amountOutMinimum; // 输出的数量，必须大于某值。最小值。
        uint160 sqrtPriceLimitX96; // 限制价格
    }

    // 指定输入的币。 返回输出的币。
    function exactInput(
        ExactInputParams calldata params
    ) external returns (uint256 amountOut);

    // 指定输出的币。
    struct ExactOutputParams {
        address tokenIn; // 输入的币
        address tokenOut; // 输出的币
        uint32[] indexPath; // 池子下标。
        address recipient; // 归属人。
        uint256 deadline; // 截止时间
        uint256 amountOut; // 输出的数量
        uint256 amountInMaximum; // 输入的数量，必须小于某值。最大值。
        uint160 sqrtPriceLimitX96; // 限制价格
    }

    // 指定输出的币。 返回输入的币。
    function exactOutput(
        ExactOutputParams calldata params
    ) external returns (uint256 amountIn);

    // 报价。指定输入的币。
    struct QuoteExactInputParams {
        address tokenIn; // 输入的币
        address tokenOut; // 输出的币
        uint32[] indexPath; // 池子下标。
        uint256 amountIn; // 输入的数量
        uint160 sqrtPriceLimitX96; // 限制价格
    }

    // 报价。指定输入的币。 返回输出的币。
    function quoteExactInput(
        QuoteExactInputParams calldata data
    ) external returns (uint256 amountOut);

    // 报价。指定输出的币。
    struct QuoteExactOutputParams {
        address tokenIn; // 输入的币
        address tokenOut; // 输出的币
        uint32[] indexPath; // 池子下标。
        uint256 amountOut; // 输出的数量
        uint160 sqrtPriceLimitX96; // 限制价格
    }

    // 报价。指定输出的币。 返回输入的币。
    function quoteExactOutput(
        QuoteExactOutputParams calldata params
    ) external returns (uint256 amountIn);
}
