// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

enum MPStatus {OPEN, DISBURSEMENT, CLOSED, FROZEN}
enum MPScheduleStatus {GROWTH, MATURED/**no further payments remaining*/, SETTLED /** no further emissions remaining */}

struct ProtoPension { 
    address owner; 
    uint256 productId; 
}

struct MPension { 
    uint256 id; 
    address creator; 
    address owner; 
    address vault; 
    uint256 maturityDate; 
    uint256 dissolutionDate; 
    MPProduct product; 
}

struct MPProduct { 
    uint256 id; 
    address provider; 
    address erc20; 
    uint256 totalContribution; 
    uint256 principalOnMaturity; 
    uint256 interest; 
    RiskType riskType; 
    FinancialSchedule contributionSchedule; 
    FinancialSchedule emissionSchedule; 
    Tolerance tolerance; 
    uint256 createdDate; 
    uint256 expiryDate; 
    uint256 units; 
}

struct MProtoProduct{ 
    address pensionCurrencyErc20; 
    RiskType riskType; 
    uint256 totalContribution; 
    uint256 principalOnMaturity; 
    uint256 interest; 
    FinancialSchedule contributionSchedule; 
    FinancialSchedule emissionSchedule;
    Tolerance tolerance; 
    uint256 lifespan; 
    uint256 units; 
}

// Money manager bond

enum BondType {TREASURY, MARKET}

struct SecurityBond { 
    uint256 id; 
    address owner; 
    uint256 amount; 
    address erc20; 
    uint256 created; 
    BondType bType; 
}

struct ProtoSecurityBond { 
    address owner; 
    uint256 amount; 
    address erc20; 
}

struct Market { 
    uint256 id; 
    address owner; 
    RiskType riskType; 
    address fromToken;
    address toToken;
    uint256 minDuration; 
    uint256 maxDuration; 
    uint256 minReturn; 
    uint256 maxReturn; 
    uint256 maxSlots; 
    uint256 bondId; 
    uint256 createDate; 
    uint256 expiryDate; 
    uint256 finalExitDate; 
}

enum ObjType {MPENSION, MARKET, TREASURY, POSITION, BOND, PRODUCT}

enum RiskType {HIGH, MEDIUM, LOW}

enum Schedule {DAILY, WEEKLY, MONTHLY, QUARTERLY}

struct FinancialSchedule { 
    Schedule schedule; 
    uint256 term; 
    uint256 minimumAmount; 
    uint256 maximumAmount;
    uint256 totalIntervals; 
    uint256 totalAmount; 
}

struct Tolerance { 
    uint256 maxGainPercentage; 
    uint256 maxLossPercentage; 
}

enum PositionStatus {OPEN, CLOSED}

struct Position { 
    uint256 id; 
    PositionStatus status; 
    uint256 mPensionId; 
    uint256 amount; 
    address token; 
    uint256 created; 
    Tolerance tolerance; 
    uint256 marketId; 
}

enum TxType {CREATE, CONTRIBUTE, DRAWDOWN, PULL, PUSH, INVEST, DIVEST, CLOSE, EXPIRE, UPDATE}

struct Tx { 
    uint256 id; 
    TxType txType; 
    address location; 
    uint256 entityId; 
    uint256 date; 
    uint256 amount; 
    address erc20; 
}