// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "../../interfaces/IMPensionVault.sol"; 
import "../../interfaces/IMedallionPensions.sol";

import "../../interfaces/market/IMPMarketManager.sol";
import "../../interfaces/treasury/IMPTreasury.sol";

import "../../interfaces/util/IRegister.sol";
import "../../interfaces/util/IVersion.sol"; 
import "../../interfaces/util/IMPTxManager.sol";
import "../../interfaces/util/IMPBondManager.sol";  

import "../../structs/MPStructs.sol";

import "../../lib/MPLib.sol";


contract MPTreasury is IMPTreasury, IVersion { 

    modifier bondHolderOnly { 
        require(IMPBondManager(register.getAddress(BOND_MANAGER_CA)).hasBond(BondType.TREASURY, msg.sender), "no treasury bond"); 
        _;
    }

    modifier adminOnly {
        require(msg.sender == register.getAddress(PENSION_ADMIN_CA), "medalion peensions admin only");
        _;
    }

    string constant name              = "RESERVED_MP_TREASURY"; 
    uint256 constant version          = 1; 

    string constant REGISTER_CA       = "RESERVED_MP_REGISTER";
    string constant PENSION_ADMIN_CA  = "RESERVED_MP_ADMIN";
    string constant MARKET_MANAGER_CA = "RESERVED_MP_MARKET_MANAGER"; 
    string constant TX_MANAGER_CA     = "RESERVED_MP_TX_MANAGER";
    string constant MEDALION_PENSIONS_CA = "RESERVED_MEDALLION_PENSIONS_CORE";
    string constant BOND_MANAGER_CA   = "RESERVED_BOND_MANAGER";

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address immutable self; 

    IRegister register; 

    address [] allowedBondTokens; 
    mapping(address=>bool) isAllowedBondTokenByAddress; 

    uint256 index; 

    uint256 [] positionIds; 
    mapping(uint256=>Position) positionById; 
    mapping(uint256=> uint256) positionIdByPensionId; 
    mapping(uint256=>uint256[]) txIdsByPositionId; 
    
    mapping(uint256=>uint256[]) openPositionsByBondId; 

    constructor (address _register) { 
        register = IRegister(_register); 
        self = address(self); 
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

    function isAllowedBondToken(address _erc20) view external returns (bool _isAllowed){
        return isAllowedBondTokenByAddress[_erc20]; 
    }

    function getPositionIds() view external returns (uint256 [] memory _positionIds){
        return positionIds; 
    }

    function getPosition(uint256 _positionId) view external returns (Position memory _position){
        return positionById[_positionId];
    }
    
    function getTxIdsByPositionId(uint256 _positionId) view external returns (uint256 [] memory _txIds){
        return txIdsByPositionId[_positionId]; 
    }

    function hasOpenPositions(uint256 _bondId) view external returns (bool _hasOpenPositions) {
        return openPositionsByBondId[_bondId].length != 0;
    }

    function getPensionPositionId(uint256 _mPensionId) view external returns (Position memory _position) { 
        return positionById[positionIdByPensionId[_mPensionId]];
    }

    function invest(uint256 _mPensionId, uint256 _marketId) external bondHolderOnly returns (uint256 _positionId, uint256 _txId){

        MPension memory pension_ = getPensionInternal(_mPensionId);
        IMPensionVault vault_ = IMPensionVault(pension_.vault);
        _positionId = getIndex(); 
        positionIds.push(_positionId);

        SecurityBond memory bond_ = IMPBondManager(register.getAddress(BOND_MANAGER_CA)).getUserBond(BondType.TREASURY, msg.sender);
        openPositionsByBondId[bond_.id].push(_positionId);
     
        (uint256 pullAmount_, uint256 vaultTxId_) = vault_.pull(_positionId);

        txIdsByPositionId[_positionId].push(vaultTxId_); 
        
        IMPMarketManager marketManager = IMPMarketManager(register.getAddress(MARKET_MANAGER_CA)); 
        Market memory market_ = marketManager.getMarket(_marketId);
        
        MPLib.transferIn(market_.fromToken, pullAmount_, self);
        
        if(market_.fromToken == NATIVE){
            marketManager.openPosition{value : pullAmount_}(_positionId, _marketId, pullAmount_); 
        }
        else {
            IERC20 erc20_ = IERC20(market_.fromToken);
            erc20_.approve(address(marketManager), pullAmount_); 
            marketManager.openPosition(_positionId, _marketId, pullAmount_); 
        }
        
        positionById[_positionId] = Position ({
                                                id : _positionId, 
                                                status :  PositionStatus.OPEN,
                                                mPensionId : _mPensionId, 
                                                amount : pullAmount_, 
                                                token : market_.fromToken,
                                                created : block.timestamp,  
                                                tolerance : pension_.product.tolerance,
                                                marketId : _marketId 
                                            }); 
        positionIdByPensionId[_mPensionId] = _positionId; 
        _txId = addTx(TxType.INVEST, ObjType.MPENSION, _mPensionId, pullAmount_ , market_.fromToken);
        txIdsByPositionId[_positionId].push(_txId);
        return (_positionId, _txId); 
    }

    function divest(uint256 _positionId) external bondHolderOnly returns (uint256 _txId){
        positionById[_positionId].status = PositionStatus.CLOSED; 
      
        IMPMarketManager marketManager_ = IMPMarketManager(register.getAddress(MARKET_MANAGER_CA)); 
        (uint256 returnAmount_, uint256 txId_) = marketManager_.closePosition(positionById[_positionId].marketId, _positionId);
        txIdsByPositionId[_positionId].push(txId_);

        // transfer money in from market 
        MPLib.transferIn(positionById[_positionId].token, returnAmount_, self);

        MPension memory pension_ = getPensionInternal(positionById[_positionId].mPensionId);
        IMPensionVault vault_ = IMPensionVault(pension_.vault);
        uint256 earnings_ = returnAmount_ - positionById[_positionId].amount; 

        // transfer money back to pension vault 
        if(positionById[_positionId].token == NATIVE){
            vault_.push{value : returnAmount_}(_positionId, positionById[_positionId].amount, earnings_ );
        }
        else {
            IERC20 erc20_ = IERC20(positionById[_positionId].token);
            erc20_.approve(address(vault_), returnAmount_); 
            vault_.push(_positionId, positionById[_positionId].amount, earnings_ );
        }

        // run book keeping 
        SecurityBond memory bond_ = IMPBondManager(register.getAddress(BOND_MANAGER_CA)).getUserBond(BondType.TREASURY, msg.sender);
        openPositionsByBondId[bond_.id] = MPLib.remove(openPositionsByBondId[bond_.id], _positionId);

         _txId = addTx(TxType.DIVEST, ObjType.MPENSION, positionById[_positionId].mPensionId, returnAmount_ ,positionById[_positionId].token);
         txIdsByPositionId[_positionId].push(_txId);
         return (_txId);
    }

    function notifyChangeOfAddress() external adminOnly returns (bool _acknowledged) { 
        register = IRegister(register.getAddress(REGISTER_CA));
        return true; 
    }

    //========================================== INTERNAL ===================================================================

    function addTx(TxType _txType, ObjType _objType, uint256 _pensionId, uint256 _amount, address _erc20) internal returns (uint256 _txId){
         return IMPTxManager(register.getAddress(TX_MANAGER_CA)).addTx(_txType,  _objType, _pensionId, self, _amount, _erc20); 
    }

    function getPensionInternal(uint256 _mPensionId) view internal returns (MPension memory _mPension){ 
          _mPension = IMedallionPensions(register.getAddress(MEDALION_PENSIONS_CA)).getPension(_mPensionId);
        return _mPension; 
    }

    function getIndex() internal returns (uint256 _index) {
        _index = index++; 
        return _index; 
    }

}