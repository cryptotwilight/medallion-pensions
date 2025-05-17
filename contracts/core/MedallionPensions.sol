// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "../interfaces/IMedallionPensions.sol";

import "../interfaces/util/IRegister.sol"; 
import "../interfaces/util/IVersion.sol"; 
import "../interfaces/util/IMPTxManager.sol"; 

import "../interfaces/product/IMPProductManager.sol";

import "../interfaces/factory/IMPVaultFactory.sol";

import "../structs/MPStructs.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol"; 
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol"; 

contract MedallionPensions is IMedallionPensions, IVersion { 

    modifier adminOnly {
        require(msg.sender == register.getAddress(PENSION_ADMIN_CA), "Pension Admin Only");
        _;
    }

    string constant name       = "RESERVED_MEDALLION_PENSIONS_CORE"; 
    uint256 constant version  = 2; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    string constant REGISTER_CA              = "RESERVED_MP_REGISTER";
    string constant PENSION_ADMIN_CA         = "RESERVED_MP_ADMIN";
    string constant FEE_TOKEN_CA             = "RESERVED_MP_FEE_TOKEN"; 
    string constant BANK_ADDRESS_CA          = "RESERVED_MP_BANK";
    string constant PENSION_VAULT_FACTORY_CA = "RESERVED_MP_VAULT_FACTORY"; 
    string constant TX_MANAGER_CA            = "RESERVED_MP_TX_MANAGER";
    string constant PRODUCT_MANAGER_CA       = "RESERVED_MP_PRODUCT_MANAGER";

    string constant PENSION_SETUP_FEE        = "PENSION_SETUP_FEE"; 

    address immutable self; 

    IRegister register; 

    uint256 index = 1; 

    uint256 [] pensionIds; 
    mapping(uint256=>bool) knownPension; 
    mapping(uint256=>MPension) pensionById; 
    mapping(address=>uint256) pensionIdByOwner; 

    mapping(string=>uint256) feeByName; 

    constructor(address _registry) { 
        register = IRegister(_registry);
        require(register.hasAddress(PENSION_ADMIN_CA), string.concat("missing address ",PENSION_ADMIN_CA ));
        require(register.hasAddress(FEE_TOKEN_CA), string.concat("missing address ",FEE_TOKEN_CA ));
        require(register.hasAddress(BANK_ADDRESS_CA), string.concat("missing address ",BANK_ADDRESS_CA ));
        require(register.hasAddress(PENSION_VAULT_FACTORY_CA), string.concat("missing address ",PENSION_VAULT_FACTORY_CA ));
        require(register.hasAddress(TX_MANAGER_CA), string.concat("missing address ",TX_MANAGER_CA ));
        require(register.hasAddress(PRODUCT_MANAGER_CA), string.concat("missing address ",PRODUCT_MANAGER_CA ));

        self = address(this);
    }

    function getName() pure external returns (string memory _name) { 
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){ 
        return version; 
    }

    function getFeeToken() view external returns (address _feeToken, string memory _name, string memory _symbol){ 
        _feeToken = register.getAddress(FEE_TOKEN_CA);
        IERC20Metadata feeToken_ = IERC20Metadata(_feeToken);
        return (_feeToken, feeToken_.name(), feeToken_.symbol()); 
    }

    function getFee(string memory _feeName) view external returns (uint256 _fee) {
        return feeByName[_feeName];
    }

    function getPension() view external returns (MPension memory _pension){
        return pensionById[pensionIdByOwner[msg.sender]]; 
    }

    function getPension(uint256 _id) view external returns (MPension memory _pension){
        return pensionById[_id]; 
    }

    function getPensionIds() adminOnly view external returns (uint256 [] memory _pensionIds) {
        return pensionIds; 
    }

    function createPension(ProtoPension memory _pPension) payable external returns (address _vault, uint256 _txId){
        collectFee(PENSION_SETUP_FEE); 
    
        MPProduct memory product_ = getProduct(_pPension.productId); 

        uint256 pensionId_ = getIndex();
        pensionIds.push(pensionId_); 
        uint256 maturityDate = block.timestamp + product_.contributionSchedule.term;
        uint256 dissolutionDate = maturityDate + product_.emissionSchedule.term; 
        _vault = getVault(pensionId_); 
        pensionById[pensionId_] = MPension({
                                            id : pensionId_, 
                                            creator : msg.sender,  
                                            owner : _pPension.owner, 
                                            vault : _vault, 
                                            maturityDate : maturityDate, 
                                            dissolutionDate : dissolutionDate, 
                                            product : product_
                                        });
        pensionIdByOwner[_pPension.owner] = pensionId_;                                   
        
        _txId = addTx(TxType.CREATE, ObjType.MPENSION, pensionId_, feeByName[PENSION_SETUP_FEE],register.getAddress(FEE_TOKEN_CA));
        return (_vault, _txId); 
    }

    function setFee(string memory _feeName, uint256 _fee) external adminOnly returns (bool _set) {
        feeByName[_feeName] = _fee; 
        return true; 
    } 

    function notifyChangeOfAddress() external adminOnly returns (bool _acknowledged) { 
        register = IRegister(register.getAddress(REGISTER_CA));
        return true; 
    }
    // ============================== INTERNAL =======================================================
    function getProduct(uint256 _productId) internal returns (MPProduct memory _product) {
        _product = IMPProductManager(register.getAddress(PRODUCT_MANAGER_CA)).getProduct(_productId);
        require(_product.expiryDate >= block.timestamp, "product expired");
        require(_product.units > 0, "insufficient inventory"); 
        IMPProductManager(register.getAddress(PRODUCT_MANAGER_CA)).updateProductInventory(_productId); 
        return _product; 
    }
    function getVault(uint256 _mPensionId) internal returns (address _vault) { 
        _vault = IMPVaultFactory(register.getAddress(PENSION_VAULT_FACTORY_CA)).createVault(_mPensionId);
        return _vault; 
    }

    function collectFee(string memory _fee) internal { 
        address feeToken_ = register.getAddress(FEE_TOKEN_CA);
        address bankAddress_ = register.getAddress(BANK_ADDRESS_CA); 
        uint256 fee_ = feeByName[_fee];

        if(feeToken_ == NATIVE) {
            require(msg.value >= feeByName[PENSION_SETUP_FEE], "insufficient pension setup fee"); 
            payable(bankAddress_).transfer(fee_); 
        }
        else { 
            IERC20 erc20_ = IERC20(feeToken_);
            erc20_.transferFrom(msg.sender, self, fee_); 
            erc20_.transfer(bankAddress_, fee_);
        }
    }

    function getIndex() internal returns (uint256 _index) {
        _index = index++; 
        return _index; 
    }

    function addTx(TxType _txType, ObjType _objType, uint256 _pensionId, uint256 _amount, address _erc20) internal returns (uint256 _txId){
         return IMPTxManager(register.getAddress(TX_MANAGER_CA)).addTx(_txType,  _objType, _pensionId, self, _amount, _erc20); 
    }
}