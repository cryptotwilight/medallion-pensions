// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "../../interfaces/util/IVersion.sol"; 
import "../../interfaces/util/IRegister.sol"; 
import "../../interfaces/util/IMPTxManager.sol"; 

contract MPTxManager is IMPTxManager, IVersion { 

    modifier mPensionsOnly {
        require(register.isKnown(msg.sender), "unknown address"); 
        _; 
    }

    modifier adminOnly {
        require(msg.sender == register.getAddress(PENSION_ADMIN_CA), "medalion peensions admin only");
        _;
    }


    string constant name = "RESERVED_MP_TX_MANAGER"; 
    uint256 constant version = 1; 

    string constant REGISTER_CA = "RESERVED_MP_REGISTER";
    string constant PENSION_ADMIN_CA         = "RESERVED_MP_ADMIN";

    IRegister register; 
    address self; 

    uint256 index; 

    uint256 [] ids; 
    mapping(uint256=>Tx) txById; 
    mapping(ObjType=>mapping(uint256=>uint256[]))txIdsByIdByObjType; 

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
    function getTx(uint256 _txId) view external returns (Tx memory _tx){
        return txById[_txId]; 
    }

    function getMPensionTx(uint256 _mPensionId) view external returns (uint256 []  memory _txIds){
        return txIdsByIdByObjType[ObjType.MPENSION][_mPensionId]; 
    }

    function addTx(TxType _txType, ObjType _objType, uint256 _id, address _location, uint256 _amount, address _erc20) external mPensionsOnly returns (uint256 _txId){ 
        _txId = getIndex(); 
        ids.push(_txId); 
        txById[_txId] = Tx({
                                id : _txId, 
                                txType : _txType,
                                location : _location,
                                entityId : _id, 
                                date : block.timestamp,
                                amount : _amount, 
                                erc20 : _erc20
                            });
        txIdsByIdByObjType[_objType][_id].push(_txId);
        return _txId; 
    }

    function notifyChangeOfAddress() external adminOnly returns (bool _acknowledged) { 
        register = IRegister(register.getAddress(REGISTER_CA));
        return true; 
    }
    //================================================= INTERNAL ========================================================================

    function getIndex() internal returns (uint256 _index) {
        _index = index++; 
        return _index; 
    }
}