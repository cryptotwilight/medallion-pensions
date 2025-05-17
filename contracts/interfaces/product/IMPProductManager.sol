// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {MPProduct} from "../../structs/MPStructs.sol";

interface IMPProductManager { 

    function getMProductIds() view external returns (uint256 [] memory _mProductIds);

    function getProduct(uint256 _productId) view external returns (MPProduct memory _product); 

    function updateProductInventory(uint256 _productId) external returns (uint256 _txId); 

}