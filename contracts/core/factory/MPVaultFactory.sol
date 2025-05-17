// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "../../interfaces/util/IRegister.sol"; 
import "../../interfaces/util/IVersion.sol"; 

import "../../interfaces/factory/IMPVaultFactory.sol"; 
import "../MPensionVault.sol"; 

contract MPVaultFactory is IMPVaultFactory, IVersion { 

    modifier medalionPensionsOnly { 
        require(msg.sender == register.getAddress(MEDALLION_PENSIONS_CA), "medalion pensions only"); 
        _;
    }

    modifier adminOnly {
        require(msg.sender == register.getAddress(PENSION_ADMIN_CA), "medalion peensions admin only");
        _;
    }

    string constant name = "RESERVED_MP_VAULT_FACTORY"; 
    uint256 constant version = 2; 

    uint256 constant vaultVersion = 3;

    string constant MEDALLION_PENSIONS_CA = "RESERVED_MEDALLION_PENSIONS_CORE"; 
    string constant PENSION_ADMIN_CA      = "RESERVED_MP_ADMIN";
    string constant REGISTER_CA = "RESERVED_MP_REGISTER";


    address immutable self; 
    IRegister register; 

    address [] vaultAddresses; 
    mapping(address=>bool) isKnownAddress; 
    mapping(uint256=>address) vaultAddressByPensionId; 


    constructor (address _register) { 
        register = IRegister(_register); 
        self = address(this); 
    }

    function getName() pure external returns (string memory _name) { 
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){ 
        return version; 
    }

    function getVaultVersion() pure external returns (uint256 _vaultVersion){
        return vaultVersion;
    }

    function getAddresses() view external adminOnly returns (address [] memory _pensionVaults){
        return vaultAddresses;
    }

    function getVaultAddressByPensionId(uint256 _mPensionId) external adminOnly view returns (address _pensionVault){
        return vaultAddressByPensionId[_mPensionId]; 
    }

    function isKnownPensionVault(address _vaultAdddress) view external returns (bool _isKnown){
        return isKnownAddress[_vaultAdddress]; 
    }

    function createVault(uint256 _mPensionId) external medalionPensionsOnly returns (address _mPensionVaultAddress) {
        _mPensionVaultAddress = address(new MPensionVault(address(register), _mPensionId)); 
        vaultAddresses.push(_mPensionVaultAddress); 
        isKnownAddress[_mPensionVaultAddress] = true; 
        vaultAddressByPensionId[_mPensionId] = _mPensionVaultAddress; 
        return _mPensionVaultAddress; 
    }

    function notifyChangeOfAddress() external adminOnly returns (bool _acknowledged) { 
        register = IRegister(register.getAddress(REGISTER_CA));
        return true; 
    }
}