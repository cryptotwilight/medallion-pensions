// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "../../interfaces/util/IRegister.sol"; 
import "../../interfaces/util/IVersion.sol"; 


contract MPRegister is IRegister, IVersion { 

    modifier adminOnly { 
        require(msg.sender == addressByName[ADMIN_CA], "admin only"); 
        _; 
    }

    string constant name = "RESERVED_MP_REGISTER"; 
    uint256 constant version = 7; 

    address immutable self; 

    string constant BANK_CA = "RESERVED_MP_BANK";
    string constant ADMIN_CA = "RESERVED_MP_ADMIN";  
    string constant FEE_TOKEN_CA = "RESERVED_MP_FEE_TOKEN";

    address [] addresses; 
    string [] names; 
    mapping(string=>bool) knownName; 
    mapping(address=>bool) isKnownAddress; 
    mapping(string=>address) addressByName; 
    mapping(address=>uint256) versionByAddress; 
    mapping(string=>uint256) versionByName; 
    mapping(string=>bool) hasAddressByName; 
    
    constructor(address _admin, address _feeToken) { 
        addAddressInternal(ADMIN_CA, _admin, 0); 
        addAddressInternal(BANK_CA, _admin, 0);
        addAddressInternal(FEE_TOKEN_CA, _feeToken, 0);  
        self = address(this); 
        addAddressInternal(name, self, version);
    }

    function getName() pure external returns (string memory _name) { 
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){ 
        return version; 
    }

    function hasAddress(string memory _name) view external returns (bool _hasAddress){
        return hasAddressByName[_name]; 
    }

    function getNames() view external returns (string [] memory _names){
        return names; 
    }

    function isKnown(address _address) view external returns (bool _isKnown) {
        return isKnownAddress[_address]; 
    } 

    function getAddress(string memory _name) view external returns (address _address){
        return addressByName[_name];
    }

    function addAddress(string memory _name, address _address, uint256 _version) external adminOnly returns (bool _added){ 
        return addAddressInternal(_name, _address, _version); 
    }

    function addVersionAddress(address _address) external adminOnly returns (bool _added){ 
        IVersion version_ = IVersion(_address); 
        return addAddressInternal(version_.getName(), _address, version_.getVersion()); 
    }

    //=========================================== INTERNAL =======================================================================

    function addAddressInternal(string memory _name, address _address, uint256 _version) internal returns (bool _added) {
        if(!knownName[_name]){
            names.push(_name);
        }
        addresses.push(_address);

        hasAddressByName[_name]     = true; 
        isKnownAddress[_address]    = true; 
        addressByName[_name]        = _address; 
        versionByAddress[_address]  = _version; 
        versionByName[_name]        = _version; 
        return true; 
    }
}