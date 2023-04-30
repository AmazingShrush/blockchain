// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract P2PEnergy{
    struct Prosumer{
        address ID;
        int energyStatus;
        uint256 balance;
        bool isRegistered;
        uint noOfTransactions;
        uint  rewardPoints;
    }
        uint energyPrice = 1 ether;
        uint fee = 10;
    mapping(address => Prosumer) internal prosumers;
    address[] internal buyerQueue;
    address[] internal sellerQueue;
    uint256 public etherRewards;


    function registerProsumer(address _prosumerAddress) internal{
        prosumers[_prosumerAddress] = Prosumer(_prosumerAddress,0,0,true,0,0);
    }
    function removeAtIndex(uint index, address[] storage array) internal {
        require(index < array.length, "Index out of bounds");
        for (uint i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
    }
    // function giveRewardTokens(address _prosumer) internal{
    //     prosumers[_prosumer].token = 1;
    //     prosumers[_prosumer].noOfTransactions = 0;
    // }
    function sellEnergy(address _prosumer,int energyUnits) internal {
        bool foundBuyer = false;
        prosumers[_prosumer].noOfTransactions += 1;
        if(prosumers[_prosumer].noOfTransactions > 3){
                    prosumers[_prosumer].rewardPoints = 1;
                    prosumers[_prosumer].noOfTransactions = 0;
        }
        for(uint i=0; i<buyerQueue.length;i++){
            if(-1*prosumers[buyerQueue[i]].energyStatus <= energyUnits){
                int y=energyUnits;
                if(-1*prosumers[buyerQueue[i]].energyStatus < energyUnits){

                    int x=energyUnits + prosumers[buyerQueue[i]].energyStatus;
                     y= energyUnits - x;
                     Prosumer storage sender = prosumers[_prosumer];
                     sender.energyStatus = x;
                     sellerQueue.push(_prosumer);
                }

                prosumers[buyerQueue[i]].energyStatus += y;

                // Trading ethers with service fee
                uint totalCost = uint(y) * energyPrice;
                uint feeAmount = (totalCost * fee) / 100;
                uint finalCost = totalCost + feeAmount;
                prosumers[buyerQueue[i]].balance -= finalCost;
                prosumers[_prosumer].balance += finalCost - feeAmount;
                etherRewards += feeAmount;
                foundBuyer = true;
                if(prosumers[buyerQueue[i]].energyStatus == 0){
                    removeAtIndex(i,buyerQueue);
                }
                
                break;
            }
        }
        if(!foundBuyer){
            Prosumer storage sender = prosumers[_prosumer];
            sender.energyStatus += energyUnits;
            sellerQueue.push(_prosumer);
        }
    }
//function to buy energy
    function buyEnergy(address _prosumer,int energyUnits) internal {

        bool foundSeller = false;
        prosumers[_prosumer].noOfTransactions += 1;
        if(prosumers[_prosumer].noOfTransactions > 3){
                     prosumers[_prosumer].rewardPoints = 1;
                     prosumers[_prosumer].noOfTransactions = 0;
        }
        for (uint i = 0; i < sellerQueue.length; i++) {
            if (prosumers[sellerQueue[i]].energyStatus >= -1 * energyUnits) {
                prosumers[sellerQueue[i]].energyStatus += energyUnits;
                //prosumers[_prosumer].energyStatus -= energyUnits;

                uint totalCost = uint(-energyUnits) * energyPrice;
                uint feeAmount = (totalCost * fee) / 100;
                uint finalCost = totalCost + feeAmount;
                prosumers[sellerQueue[i]].balance += finalCost - feeAmount;
                prosumers[_prosumer].balance -= finalCost;
                etherRewards += feeAmount;
                foundSeller = true;
                if(prosumers[sellerQueue[i]].energyStatus == 0){
                    removeAtIndex(i,sellerQueue);
                }
                
                 

                break;
            }
        }
        if (!foundSeller) {
            Prosumer storage sender = prosumers[_prosumer];
            sender.energyStatus += energyUnits;
            buyerQueue.push(_prosumer);
        }
        
    }

}

contract MainContract is P2PEnergy{
    modifier prosumerIsRegistered(){
        require(prosumers[msg.sender].isRegistered == true,"The prosumer is not registered");
        _;
    }

    modifier notRegisteredProsumer(){
        require(prosumers[msg.sender].isRegistered == false, " The prosumer is already registered");
        _;
    }

    modifier checkFunds(int energy){
        uint energyUnits;
        
        if(energy < 0){
        energyUnits= uint(-energy);
        int requestsSent = prosumers[msg.sender].energyStatus;
        uint256 amountAvailable=prosumers[msg.sender].balance;

        uint totalCost = energyUnits * energyPrice;
        uint feeAmount = (totalCost * fee) / 100;
        uint finalCost = totalCost + feeAmount;
        //uint256 newAmountCheck = energyUnits * 1 ether + energyUnits * 1 ether * 0.10;
        uint256 amountAvailableRequest=prosumers[msg.sender].balance - uint(-requestsSent) * 1 ether;
        require(amountAvailable >= finalCost, " Insufficient balance in prosumer's account");
        require(amountAvailableRequest >= energyUnits * 1 ether, "Pending request amount exceeds the available balance in prosumer's");
        }
        _;
    }


    function register() public notRegisteredProsumer{
        registerProsumer(msg.sender);
    }

    function sendEnergyRequest(int energy) public prosumerIsRegistered checkFunds(energy){
       
        if(energy > 0){
            sellEnergy(msg.sender,energy);
        }else{
            buyEnergy(msg.sender,energy);
        }
    }
      //function to check current energy status
    function checkCurrentEnergyStatus() view public prosumerIsRegistered returns (int energyStatus) {
        return prosumers[msg.sender].energyStatus;
    }

    //function to check current balance
    function checkCurrentBalance() public prosumerIsRegistered view returns (uint) {
        return prosumers[msg.sender].balance/ 10**18;
    }

    function checkTransactions() public prosumerIsRegistered view returns (uint noOfTransactions){
        return prosumers[msg.sender].noOfTransactions;
    }

    function checkRewardPoints() public prosumerIsRegistered view returns (uint){
        return prosumers[msg.sender].rewardPoints;
    }

    //Delete this 
    function checkP2PContractRewards()public view returns (uint){
        return etherRewards/ 10**18;
    }

    function exchangeRewardPointsForEthers(uint _rewardPoints) public prosumerIsRegistered{
        require(prosumers[msg.sender].rewardPoints >= _rewardPoints,"Sorry, you do not have sufficient reward points in your account");
        require(etherRewards > _rewardPoints,"Insufficient funds in contract, please try with lesser points or try again later");
        uint amountOfRewardEthers = _rewardPoints * 0.5 ether;
        etherRewards -= amountOfRewardEthers;
        prosumers[msg.sender].balance += amountOfRewardEthers;
        prosumers[msg.sender].rewardPoints -= _rewardPoints;
    }

     function deposit() public payable prosumerIsRegistered {
        require(msg.value > 0, "Deposit amount must be greater than zero.");
        prosumers[msg.sender].balance += msg.value;
    }


    function withdraw() public prosumerIsRegistered {
            require(prosumers[msg.sender].energyStatus >= 0, "Cannot withdraw funds while energy deficit exists.");
            uint amount = prosumers[msg.sender].balance;
            require(amount > 0, "Insufficient balance.");
            prosumers[msg.sender].balance = 0;
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "Withdrawal failed.");
        }
}