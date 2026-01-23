// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;


import {Script} from "forge-std/Script.sol";


contract HelperConfig is Script {

     /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error HelperConfig__InvalidChainId();


     /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        uint256 deployerKey;
        address initialOwner;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/


    uint256 public constant DEAFULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    /*//////////////////////////////////////////////////////////////
                            CHAIN IDs
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;


    constructor() {
         if(block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getEthSepoliaConfig();
        } else if(block.chainid == LOCAL_CHAIN_ID) {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    

    function getEthSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            deployerKey: vm.envUint("PRIVATE_KEY"),
            initialOwner: vm.envAddress("INITIAL_OWNER")
             });
    }

    function getAnvilConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            deployerKey: DEAFULT_ANVIL_PRIVATE_KEY,
            initialOwner: vm.addr(DEAFULT_ANVIL_PRIVATE_KEY)
             });
    }

}