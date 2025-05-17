// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "../interfaces/IMPensionVault.sol"; 

import "../interfaces/util/IVersion.sol";
import "../interfaces/util/IRegister.sol"; 
import "../interfaces/util/IMPTxManager.sol"; 

import "../interfaces/IMedallionPensions.sol"; 

import "../structs/MPStructs.sol"; 

import "../lib/MPLib.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 

struct PensionMetrics { 
    uint256 contributions; 
    uint256 lastContributionDate; 
    uint256 lastPullDate; 
    uint256 issuedPrincipal; 
    bool isInTreasury;  
}
contract MPensionVault is IMPensionVault, IVersion { 

    modifier semaphore { 
        require(!locked, "vault locked");
        require(status != MPStatus.CLOSED, "vault closed");  
        _; 
    }

    modifier ownerOnly { 
        require(msg.sender == getPensionInternal().owner, "owner only");
        _; 
    }

    modifier adminOnly {
        require(msg.sender == register.getAddress(PENSION_ADMIN_CA), "Pension Admin Only");
        _;
    }

    modifier treasuryOnly { 
        require(msg.sender == register.getAddress(TREASURY_CA), "Treasury Only");
        _; 
    }

    string constant name = "MEDALLION_PENSION_VAULT"; 
    uint256 constant version  = 18;

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    string constant REGISTER_CA          = "RESERVED_MP_REGISTER";
    string constant MEDALION_PENSIONS_CA = "RESERVED_MEDALLION_PENSIONS_CORE";
    string constant PENSION_ADMIN_CA     = "RESERVED_MP_ADMIN";
    string constant TX_MANAGER_CA        = "RESERVED_MP_TX_MANAGER";
    string constant BANK_CA              = "RESERVED_MP_BANK";
    string constant TREASURY_CA          = "RESERVED_MP_TREASURY"; 

    uint256 immutable pensionId; 
    address immutable self;

    bool locked = false; 
    MPStatus status; 
    MPScheduleStatus scheduleStatus; 

    IRegister register; 

   
    uint256 pensionBalance;
    uint256 emissionBalance; 

    PensionMetrics metrics; 

    mapping(uint256=>uint256[]) txIdsByTreasuryId; 

    constructor(address _register, uint256 _mPensionId) {
        register = IRegister(_register); 
        pensionId = _mPensionId; 
        status = MPStatus.OPEN; 
        scheduleStatus = MPScheduleStatus.GROWTH; 
        self = address(this);
    }

    function getName() pure external returns (string memory _name) { 
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){ 
        return version; 
    }

    function getStatus() view external returns (MPStatus _status) {
        return status; 
    }

    function getPension() view external returns (MPension memory _mPension){
      return getPensionInternal();
    }

    function getBalance() view external returns (uint256 _balance){
        return pensionBalance; 
    }

    function getPensionMetrics() view external returns (PensionMetrics memory _metrics) {
        return metrics; 
    }

    function getTx(uint256 _treasuryId) view external returns (uint256 [] memory _txId){
        return txIdsByTreasuryId[_treasuryId];
    }

    function contribute(uint256 _amount) payable external returns (uint256 _txId){
        locked = true; // lock pension
        require(metrics.lastContributionDate <= block.timestamp, "contributions too frequent wait required " );
        require(scheduleStatus != MPScheduleStatus.MATURED, "pension matured");
        require(status == MPStatus.OPEN, "pension not open");

        MPension memory pension_ = getPensionInternal(); 
        metrics.lastContributionDate += MPLib.getSeconds(pension_.product.contributionSchedule.schedule); 

        require(_amount >= pension_.product.contributionSchedule.minimumAmount && _amount <= pension_.product.contributionSchedule.maximumAmount, "invalid contribution either raise or lower amount");

        address erc20Address_ = pension_.product.erc20; 
        MPLib.transferIn(erc20Address_, _amount, self);

        pensionBalance += _amount; 
        metrics.contributions++; 
       
        //checkMaturity(pension_); 
        
        //_txId = addTx(TxType.CONTRIBUTE, ObjType.MPENSION, pensionId, _amount, pension_.product.erc20);

        locked = false; // unlock pension
        return _txId;  
    }

    function drawdown() external ownerOnly semaphore returns (uint256 _txId){
        MPension memory pension_ = getPensionInternal(); 
 
        locked = true; 
        require(status == MPStatus.DISBURSEMENT, "invalid pension status"); 
        require(scheduleStatus != MPScheduleStatus.SETTLED, "pension settled");

        uint256 emmission_ = pension_.product.emissionSchedule.minimumAmount;  
        require(pensionBalance >= emmission_, "insufficient emmission balance");       
        address owner_ = pension_.owner; 
        pensionBalance -= emmission_; 

        if(pension_.product.erc20 == NATIVE) {
            payable(owner_).transfer(emmission_);
        }
        else { 
            IERC20 erc20_ = IERC20(pension_.product.erc20);
            erc20_.transfer(owner_, emmission_); 
        }
        checkSettlement(pension_);
        _txId = addTx(TxType.DRAWDOWN, ObjType.MPENSION, pensionId, emmission_, pension_.product.erc20);
        locked = false; // unlock pension
        return _txId;  
    }

    function close() external adminOnly semaphore returns (uint256 _txId){
        MPension memory pension_ = getPensionInternal(); 
        require(status != MPStatus.CLOSED, "pension closed"); 
        require(!metrics.isInTreasury, "pension in treasury");
        locked = true; 
        status = MPStatus.CLOSED; 
        uint256 settlement_ = 0;
        if(pension_.product.erc20 == NATIVE) {
            settlement_ = self.balance; 
            payable(pension_.owner).transfer(settlement_);
        }
        else {
            IERC20 erc20_ = IERC20(pension_.product.erc20);
            settlement_ = erc20_.balanceOf(self); 
            erc20_.transfer(pension_.owner, settlement_);
        }
        
        _txId = addTx(TxType.CLOSE, ObjType.MPENSION, pensionId, settlement_, pension_.product.erc20);
        return _txId;  
    }

    function withdraw(address _erc20) adminOnly external returns (uint256 _amount) {
        require(status == MPStatus.CLOSED, "pension not closed");
        address bank_ = register.getAddress(BANK_CA); 
        if(_erc20 == NATIVE) {
            _amount = self.balance; 
            payable(bank_).transfer(_amount);
        }
        else { 
            IERC20 erc20_ = IERC20(_erc20);
            _amount = erc20_.balanceOf(self);
            erc20_.transfer(bank_, _amount); 
        }
        return _amount; 
    }

    // Treasurey functions 

    function pull(uint256 _treasuryId) external semaphore treasuryOnly returns (uint256 _principal, uint256 _txId){
        MPension memory pension_ = getPensionInternal(); 
        require(status == MPStatus.OPEN, "invalid pension pull state" );
        locked = true; 
        require(!metrics.isInTreasury,"vault already pulled"); 
        metrics.isInTreasury = true; 
        _principal = pensionBalance;
        metrics.issuedPrincipal = _principal;  

        address erc20Address_ = pension_.product.erc20; 
        if(erc20Address_ == NATIVE) {
            payable(msg.sender).transfer(_principal);
        }
        else { 
            IERC20 erc20_ = IERC20(erc20Address_);
            erc20_.approve(msg.sender, _principal);
        }

        _txId = addTx(TxType.PULL, ObjType.MPENSION, pensionId, _principal, pension_.product.erc20);
        txIdsByTreasuryId[_treasuryId].push(_txId);
        locked = false; // unlock pension 
        return (_principal, _txId);
    } 

    function push(uint256 _treasuryId, uint256 _principal, uint256 _earnings)  payable external semaphore treasuryOnly returns (uint256 _txId){
        locked = true; 

        MPension memory pension_ = getPensionInternal();     
        require(_principal >= metrics.issuedPrincipal, "insufficient principal returned");

        uint256 transmittedTotal_ = _principal + _earnings; 

        require(metrics.isInTreasury, "vault not pulled"); 

        address erc20Address_ = pension_.product.erc20; 
        if(erc20Address_ == NATIVE) {
            require(msg.value >= transmittedTotal_, "insuffient transmitted value"); 
        }
        else { 
            IERC20 erc20_ = IERC20(erc20Address_);
            erc20_.transferFrom(msg.sender, self, transmittedTotal_);
        }
        uint256 interimDifferential = pensionBalance - metrics.issuedPrincipal; 
        pensionBalance = interimDifferential + metrics.issuedPrincipal + _earnings; // capture any payments during treasury process. Spam capital will be removed on dissolution of the pension
        
        checkMaturity(pension_);
        _txId = addTx(TxType.CONTRIBUTE, ObjType.MPENSION, pensionId, transmittedTotal_, pension_.product.erc20);
        txIdsByTreasuryId[_treasuryId].push(_txId);

        metrics.isInTreasury = false;  // remove 
        locked = false; // unlock pension
        return _txId;  
    }

    function notifyChangeOfAddress() external adminOnly returns (bool _acknowledged) { 
        register = IRegister(register.getAddress(REGISTER_CA));
        return true; 
    }

     //============================ INTERNAL =========================================================
    function addTx(TxType _txType,ObjType _objType, uint256 _pensionId, uint256 _amount, address _erc20) internal returns (uint256 _txId){
         return IMPTxManager(register.getAddress(TX_MANAGER_CA)).addTx(_txType, _objType, _pensionId, self, _amount, _erc20); 
    }
 

    function checkMaturity(MPension memory _pension) internal { 
        if(pensionBalance >= _pension.product.contributionSchedule.totalAmount) { 
            scheduleStatus = MPScheduleStatus.MATURED; 
            status = MPStatus.DISBURSEMENT; 
        }
    }

    function checkSettlement(MPension memory _pension) internal { 
        if(emissionBalance >= _pension.product.emissionSchedule.totalAmount ) {
            scheduleStatus = MPScheduleStatus.SETTLED;
        }
    }

    function getPensionInternal() view internal returns (MPension memory _mPension){ 
          _mPension = IMedallionPensions(register.getAddress(MEDALION_PENSIONS_CA)).getPension(pensionId);
        return _mPension; 
    }



}