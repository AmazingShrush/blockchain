
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title P2PEnergyTradingContract
 * @dev P2P trading of energy units
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract P2PEnergyTradingContract {

    struct Prosumer {
        address prosumerId;
        uint energyStatus;
        uint256 balance;
        bool isRegistered;
    }

    //prosumer mapping to store energyStatus and balance for a prosumer in network
    mapping(address => Prosumer) public prosumers;

    //Queues for storing buy/sell requests
    address[] public buyerQueue;
    address[] public sellerQueue;


    //function to register prosumer
    function registerProsumer(address _prosumer) public {
        prosumers[_prosumer] = Prosumer(_prosumer,0,0,true);
    }

    //function to buy energy
    function buyEnergy(address _prosumer,uint energyUnits) public {

        bool foundSeller = false;
        for (uint i = 0; i < sellerQueue.length; i++) {
            if (prosumers[sellerQueue[i]].energyStatus >= energyUnits) {
                prosumers[sellerQueue[i]].energyStatus -= energyUnits;
                prosumers[_prosumer].energyStatus += energyUnits;
                prosumers[sellerQueue[i]].balance += energyUnits;
                foundSeller = true;
                break;
            }
        }
        if (!foundSeller) {
            Prosumer storage sender = prosumers[_prosumer];
            sender.energyStatus += energyUnits;
            buyerQueue.push(_prosumer);
        }
        
    }

    //function to get prosumer details
    function getProsumerDetails(address _prosumer) public view returns (uint energyStatus,uint balance,bool isRegistered) {
        energyStatus = prosumers[_prosumer].energyStatus;
        balance = prosumers[_prosumer].balance;
        isRegistered = prosumers[_prosumer].isRegistered;
    }

    function getProsumerData(address _prosumer) external view returns (Prosumer memory){
            return prosumers[_prosumer];
    }

    //function to sell energy
    function sellEnergy(address _prosumer,uint energyUnits) public {
        bool foundBuyer = false;
        for (uint i = 0; i < buyerQueue.length; i++) {
            if (prosumers[buyerQueue[i]].energyStatus <= energyUnits) {
                prosumers[sellerQueue[i]].energyStatus += energyUnits;
                prosumers[buyerQueue[i]].energyStatus -= energyUnits;
                prosumers[_prosumer].balance += energyUnits;
                foundBuyer = true;
                break;
            }
        }
        if (!foundBuyer) {
           Prosumer storage sender = prosumers[_prosumer];
            sender.energyStatus += energyUnits;
            sellerQueue.push(_prosumer);
        }
        
    }
    

    function calculateFees() pure private returns (uint){
        //incentive mechanism
        return 1; //assumption 1 ether is equivalent to 1 energy unit
    }

}

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

    modifier hasEnoughFunds(int energyUnits) {
        uint energyUnits2=uint(energyUnits);
        ( ,uint balance ,) = getProsumerDetails(msg.sender);
        require(balance >= energyUnits2 * 1 ether, "Prosumer doesn't have sufficient balance");
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
    function createEnergyRequestOrder(int energyUnits) public onlyRegisteredProsumer hasEnoughFunds(energyUnits) {
         
        if(energyUnits > 0){
            uint energyUnits2 = uint(energyUnits);
            sellEnergy(msg.sender,energyUnits2);
        }else{
            uint energyUnits2 = uint(energyUnits);
            buyEnergy(msg.sender,energyUnits2);
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

