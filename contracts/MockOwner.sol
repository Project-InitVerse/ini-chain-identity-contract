// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./InterfaceProvider.sol";
import "./InterfaceAuditor.sol";
contract MockOwner {
    address public owner;
    address public admin;
    address public factory;
    address public auditor;
    function setfactory(address a,address b) external{
        factory = a;
        auditor = b;
    }
    function setOwner(address a) external{
        owner = a;
        admin = a;
    }
    function mockAttack(bool a,address provider) external{
        if(a){
            IProviderFactory(factory).changeProviderResource(3,6,9,true);
            IProviderFactory(factory).changeProviderResource(5,5,5,true);
        }else{
            IAuditorFactory(auditor).reportProviderState(provider,providerState.checkFail);
        }
    }
}
