
// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./P2PEnergyTradingContract.sol";

/**
 * @title MainEnergyTradingContract
 * @dev Main contract for trading of energy units
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract MainEnergyTradingContract is P2PEnergyTradingContract{

    modifier onlyRegisteredProsumer() {
        ( , ,bool isRegistered) = getProsumerDetails(msg.sender);
        require(isRegistered, "Prosumer not registered");
        _;
    }

    modifier notRegisteredProsumer() {
        ( , ,bool isRegistered) = getProsumerDetails(msg.sender);
        require(!isRegistered, "Prosumer already registered");
        _;
    }

    modifier hasEnoughFunds(uint energyUnits) {
        ( ,uint balance ,) = getProsumerDetails(msg.sender);
        require(balance >= energyUnits * 1 ether, "Prosumer doesn't have sufficient balance");
        _;
    }

    modifier isEnergyDeficit(uint energyUnits) {
        (uint energyStatus , ,) = getProsumerDetails(msg.sender);
        require(energyStatus >= 0, "Cannot withdraw funds while energy deficit exists.");
        _;
    }

    //function to register prosumer
    function register() public notRegisteredProsumer {
        registerProsumer(msg.sender);
    }


    //function to create energy order 
    function createEnergyRequestOrder(uint energyUnits) public onlyRegisteredProsumer hasEnoughFunds(energyUnits) {
         
        if(energyUnits > 0){
            sellEnergy(msg.sender,energyUnits);
        }else{
            buyEnergy(msg.sender,energyUnits);
        }
    }

    //function to check current energy status
    function checkCurrentEnergyStatus() view public onlyRegisteredProsumer returns (uint energyStatus) {
        (energyStatus , ,) = getProsumerDetails(msg.sender);
    }

    //function to check current balance
    function checkCurrentBalance() public onlyRegisteredProsumer view returns (uint balance) {
        ( ,balance ,) = getProsumerDetails(msg.sender);
    }

    function deposit() public payable onlyRegisteredProsumer {
        require(msg.value > 0, "Deposit amount must be greater than zero.");
        prosumers[msg.sender].balance += msg.value;
    }

    function withdraw() public onlyRegisteredProsumer {
        require(prosumers[msg.sender].energyStatus >= 0, "Cannot withdraw funds while energy deficit exists.");
        uint amount = prosumers[msg.sender].balance;
        require(amount > 0, "Insufficient balance.");
        prosumers[msg.sender].balance = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed.");
    }
}

