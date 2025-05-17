// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "../../interfaces/treasury/IMPTreasury.sol";

import "../../interfaces/market/IMPMarketManager.sol";

import "../../interfaces/util/IMPBondManager.sol";
import "../../interfaces/util/IVersion.sol";
import "../../interfaces/util/IRegister.sol";
import "../../interfaces/util/IMPTxManager.sol";

import {SecurityBond, BondType} from "../../structs/MPStructs.sol";

import "../../lib/MPLib.sol";

contract BondManager is IMPBondManager, IVersion { 

    modifier bondHolderOnly(uint256 _bondId) {
        require(msg.sender == bondById[_bondId].owner, "bond holder only");
        _; 
    }

    string constant name = "RESERVED_MP_BOND_MANAGER";
    uint256 constant version = 1; 

    string constant TX_MANAGER_CA   = "RESERVED_MP_TX_MANAGER";
    string constant TREASURY_CA     = "RESERVED_MP_TREASURY";
    string constant MARKET_MANAGER_CA = "RESERVED_MP_MARKET_MANAGER";
    address constant NATIVE         = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address immutable self; 
    uint256 index; 

    uint256 [] bondIds; 
    mapping(uint256=>SecurityBond) bondById; 
    mapping(BondType=>mapping(address=>uint256)) bondIdByUserByBondType; 
    mapping(BondType=>mapping(address=>bool)) hasBondByUserByType;

    address [] allowedBondTokens; 
    mapping(address=>bool) isAllowedBondToken; 

    IRegister register; 
   
    constructor(address _register) {
        register = IRegister(_register);
        self = address(this);
    }

    function getName() pure external returns (string memory _name) { 
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){ 
        return version; 
    }

    function getAllowedBondTokens() view external returns (address [] memory _erc20){
        return allowedBondTokens;
    }

    function getBondById(uint256 _bondId) view external returns (SecurityBond memory _bond){
        return bondById[_bondId]; 
    }

    function getUserBond(BondType _type, address _user) view external returns (SecurityBond memory _bond) {
        return bondById[bondIdByUserByBondType[_type][_user]];
    }

    function hasBond(BondType _type, address _user) view external returns (bool _hasBondType){ 
        return hasBondByUserByType[_type][_user]; 
    }

    function placeBond(BondType _type, uint256 _amount, address _erc20) payable external returns (uint256 _bondId, uint256 _txId){
            require(!hasBondByUserByType[_type][msg.sender], "bond type already held");
            hasBondByUserByType[_type][msg.sender] = true; 
            MPLib.transferIn(_erc20, _amount, self); 

            _bondId = getIndex(); 
            bondIds.push(_bondId);
            
            bondById[_bondId] = SecurityBond({
                                            id : _bondId,  
                                            owner : msg.sender,  
                                            amount : _amount,  
                                            erc20 : _erc20, 
                                            created : block.timestamp,
                                            bType : _type
                                            });
            bondIdByUserByBondType[_type][msg.sender] =_bondId; 
            return (_bondId, _txId); 
    }

    function releaseBond(uint256 _bondId) external bondHolderOnly(_bondId) returns (uint256 _txId){
        SecurityBond memory bond_ = bondById[_bondId];
        if(bondById[_bondId].bType == BondType.TREASURY) {
            // require no open positions 
            require(!IMPTreasury(register.getAddress(TREASURY_CA)).hasOpenPositions(_bondId), "treasury bond has open positions");
        }
        if(bondById[_bondId].bType == BondType.MARKET) {
            // require no open positions 
            require(!IMPMarketManager(register.getAddress(MARKET_MANAGER_CA)).hasOpenPositions(_bondId), "market bond has open positions");
        }

        if(bond_.erc20 == NATIVE){
            payable(bond_.owner).transfer(bond_.amount);
        }
        else {
            IERC20 erc20_ = IERC20(bond_.erc20 );
            erc20_.transfer(bond_.owner, bond_.amount);
        }
        delete bondIdByUserByBondType[bond_.bType][msg.sender];
        hasBondByUserByType[bond_.bType][msg.sender] = false; 
        return _txId; 
    }

    function setAllowedBondTokens(address []  memory _erc20s) external returns (bool _set) {
        allowedBondTokens = _erc20s; 
        return true; 
    }

    //=========================================== INTERNAL ==============================================================

    function addTx(TxType _txType, ObjType _objType, uint256 _pensionId, uint256 _amount, address _erc20) internal returns (uint256 _txId){
         return IMPTxManager(register.getAddress(TX_MANAGER_CA)).addTx(_txType,  _objType, _pensionId, self, _amount, _erc20); 
    }

    function getIndex() internal returns (uint256 _index) {
        _index = index++; 
        return _index; 
    }
}