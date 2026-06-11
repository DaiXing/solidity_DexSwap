// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPool {}

// 铸造的回调
interface IMintCallback {
    function mintCallback(
        uint256 amount0Owed, // 币0的数量。给与
        uint256 amount1Owed, // 币1的数量。给与
        bytes calldata data // 数据
    ) external;
}
// 交换的回调
interface ISwapCallback {
    function swapCallback(
        uint256 amount0Delta, // 币0的数量。变化量
        uint256 amount1Delta, // 币1的数量。变化量
        bytes calldata data // 数据
    ) external;
}
