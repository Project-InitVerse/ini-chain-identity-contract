// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./IPunishContract.sol";
import "./InterfaceProvider.sol";


contract PunishContract is IPunishContract {
    // TODO for formal
    IProviderFactory public constant factory_address = IProviderFactory(0x000000000000000000000000000000000000C003);
    // TODO for test
    //IProviderFactory public factory_address;
    mapping(uint256 => PunishItem) public index_punish_items;
    mapping(address => PunishItem[]) public provider_punish_items;
    uint256 public current_index;
    constructor(){
        current_index = 0;
    }
    function newPunishItem(address owner, uint256 punish_amount, uint256 balance_left) external override {
        if(factory_address.getProvideContract(owner) != msg.sender){
            return;
        }
        PunishItem memory new_data;
        new_data.punish_owner = owner;
        new_data.punish_amount = punish_amount;
        new_data.balance_left = balance_left;
        new_data.block_number = block.number;
        new_data.block_timestamp = block.timestamp;
        index_punish_items[current_index] = new_data;
        provider_punish_items[owner].push(new_data);
        current_index = current_index + 1;
    }
    function getProviderPunishLength(address provider)external view returns(uint256){
        return provider_punish_items[provider].length;
    }
//    function setFactoryAddr(address fac_addr) external {
//        factory_address = IProviderFactory(fac_addr);
//    }
}
