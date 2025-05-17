// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {Position, SecurityBond} from "../../structs/MPStructs.sol";

interface IMPTreasury { 

    


    function getPositionIds() view external returns (uint256 [] memory _positionIds); 

    function getPosition(uint256 _positionId) view external returns (Position memory _position); 

    function hasOpenPositions(uint256 _bondId) view external returns (bool _hasOpenPositions);


    function invest(uint256 _mPensionId, uint256 _market) external returns (uint256 _positionId, uint256 _txId); 

    function divest(uint256 _positionId) external returns (uint256 _txId); 


}
