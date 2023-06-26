// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct PunishItem {
    address punish_owner;
    uint256 punish_amount;
    uint256 balance_left;
    uint256 block_number;
    uint256 block_timestamp;
}

interface IPunishContract {
    function newPunishItem(address owner, uint256 punish_amount, uint256 balance_left) external;
}
