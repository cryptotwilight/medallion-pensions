// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;


import "../../interfaces/util/IRegister.sol"; 
import "../../interfaces/util/IVersion.sol"; 

import "../../interfaces/product/IMPProductManager.sol";

import "../../structs/MPStructs.sol";

import "../../interfaces/util/IMPTxManager.sol"; 


contract MPProductManager is IMPProductManager, IVersion { 

    modifier productOwnerOnly (uint256 _productId) { 
        require(productById[_productId].provider == msg.sender, "product provider only"); 
        _;
    }

    modifier medallionPensionsOnly() { 
        require(msg.sender == register.getAddress(MEDALION_PENSIONS_CA), "medalion pensions only");
        _; 
    }

    modifier adminOnly {
        require(msg.sender == register.getAddress(PENSION_ADMIN_CA), "medalion peensions admin only");
        _;
    }


    string constant name = "RESERVED_MP_PRODUCT_MANAGER"; 
    uint256 constant version = 2; 

    string constant TX_MANAGER_CA        = "RESERVED_MP_TX_MANAGER";
    string constant MEDALION_PENSIONS_CA = "RESERVED_MEDALLION_PENSIONS_CORE"; 
    string constant REGISTER_CA = "RESERVED_MP_REGISTER";
    string constant PENSION_ADMIN_CA         = "RESERVED_MP_ADMIN";

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address immutable self; 

    IRegister register; 

    uint256 index; 

    uint256 [] productIds; 
    mapping(uint256=>bool)isKnownByProductId; 
    mapping(uint256=>MPProduct) productById; 

    mapping(address=>uint256[]) productIdsByOwner; 

    constructor(address _register) {
        register = IRegister(_register); 
        require(register.hasAddress(TX_MANAGER_CA), string.concat("missing address ",TX_MANAGER_CA ));
        self = address(this); 
    }

    function getName() pure external returns (string memory _name) { 
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){ 
        return version; 
    }

    function getMProductIds() view external returns (uint256 [] memory _mProductIds){
        return productIds; 
    }

    function getProduct(uint256 _productId) view external returns (MPProduct memory _product){
        return productById[_productId]; 
    }

    function isKnownProduct(uint256 _productId) view external returns (bool _isKnown){
        return isKnownByProductId[_productId]; 
    }

    function getProductIdsByOwner() view external returns (uint256 [] memory _productIds) {
        return productIdsByOwner[msg.sender]; 
    }

    function createProduct(MProtoProduct memory _protoProduct) external returns (uint256 _productId, uint256 _txId) { 
        _productId = getIndex(); 
        productIds.push(_productId);
        productIdsByOwner[msg.sender].push(_productId);
        isKnownByProductId[_productId] = true; 
        productById[_productId] = MPProduct ({
                                              id : _productId, 
                                              provider : msg.sender, 
                                              erc20 : _protoProduct.pensionCurrencyErc20, 
                                              totalContribution : _protoProduct.totalContribution, 
                                              principalOnMaturity : _protoProduct.principalOnMaturity,
                                              interest : _protoProduct.interest, 
                                              riskType : _protoProduct.riskType, 
                                              contributionSchedule : _protoProduct.contributionSchedule,
                                              emissionSchedule  : _protoProduct.emissionSchedule,
                                              tolerance : _protoProduct.tolerance, 
                                              createdDate : block.timestamp, 
                                              expiryDate : block.timestamp + _protoProduct.lifespan, 
                                              units : _protoProduct.units
                                            }); 
        _txId = addTx(TxType.CREATE, ObjType.PRODUCT,_productId, 0, _protoProduct.pensionCurrencyErc20); 
        return (_productId, _txId); 
    }

    function expireProduct(uint256 _productId) productOwnerOnly(_productId) external returns (uint256 _txId){ 
        productById[_productId].expiryDate = block.timestamp; 
        _txId = addTx(TxType.EXPIRE, ObjType.PRODUCT, _productId, 0, address(0)); 
        return _txId; 
    }
 
    function updateProductInventory(uint256 _productId) medallionPensionsOnly external returns (uint256 _txId){
        productById[_productId].units--;
        _txId = addTx(TxType.UPDATE, ObjType.PRODUCT, _productId, 0, address(0)); 
        return _txId; 
    }

    function notifyChangeOfAddress() external adminOnly returns (bool _acknowledged) { 
        register = IRegister(register.getAddress(REGISTER_CA));
        return true; 
    }
    //============================================ INTERNAL =================================================================

    function getIndex() internal returns (uint256 _index){
        _index = index++; 
        return _index; 
    }

    function addTx(TxType _txType, ObjType _objType, uint256 _id, uint256 _amount, address _erc20) internal returns (uint256 _txId){
         return IMPTxManager(register.getAddress(TX_MANAGER_CA)).addTx(_txType, _objType, _id, self, _amount, _erc20); 
    }
}