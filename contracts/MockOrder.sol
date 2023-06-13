pragma solidity ^0.8.0;

import "./InterfaceOrderFactory.sol";
import "hardhat/console.sol";

contract MockOrder is IOrderFactory {
    mapping(address => uint256) public cc;

    function set() public {
        cc[msg.sender] = 1;
    }

    function checkIsOrder(address orderAddress) external override view returns (uint256){
        return cc[orderAddress];
    }

    function get_minimum_deposit_amount() external view returns (uint256){
        return 1 ether;
    }

    function getOrder(uint256 orderId) external view returns (Order memory){
        Order memory ret;
        return ret;
    }
}
