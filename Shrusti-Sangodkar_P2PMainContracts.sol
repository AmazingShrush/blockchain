// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
/// @title A peer to peer smart contract with an incentive mechanism
/// @author Shrusti S. Sangodkar

contract P2PEnergy{
    uint energyPrice = 1 ether;

    // Struct representing a prosumer
    struct Prosumer{
        address ID; //Stores the address of the prosumer
        int energyStatus; // Energy status can be positive or negative, indicating the amount of energy the prosumer can supply or needs to buy
        uint256 balance; // Prosumer's account balance
        bool isRegistered; // true if prosumer is registered, else false
    }

    mapping(address => Prosumer) internal prosumers; // Mapping from prosumer addresses to their Prosumer struct
    address[] internal buyerQueue; // Queue of buyers waiting to buy energy
    address[] internal sellerQueue; // Queue of sellers waiting to sell energy
    
    // Function to register a new prosumer
    function registerProsumer(address _prosumerAddress) internal{
        prosumers[_prosumerAddress] = Prosumer(_prosumerAddress,0,0,true);
    }
    
    // Function to remove an element from an array
    function removeAtIndex(uint index, address[] storage array) internal {
        require(index < array.length, "Index out of bounds");
        for (uint i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
    }

    // Function for a seller to sell energy to a buyer
    function sellEnergy(address _prosumer,int energyUnits) internal {
        bool foundBuyer = false;

        //Iterating through buyer queue to search for buyers
        for(uint i=0; i<buyerQueue.length;i++){
            if(-1*prosumers[buyerQueue[i]].energyStatus <= energyUnits){
                int actualTransferableEnergy=energyUnits;
                
                //Condition to calculate transferable energy is it is less than the available energy units
                if(-1*prosumers[buyerQueue[i]].energyStatus < energyUnits){
                    int differenceInEnergy = energyUnits + prosumers[buyerQueue[i]].energyStatus;
                     actualTransferableEnergy= energyUnits - differenceInEnergy;
                     
                      //Store surplus energy in the seller queue
                     Prosumer storage sender = prosumers[_prosumer];
                     sender.energyStatus = differenceInEnergy ;
                     sellerQueue.push(_prosumer);
                }

                //Transfer of energy to buyer
                prosumers[buyerQueue[i]].energyStatus += actualTransferableEnergy;
                
                // Update the balances of the buyer and the seller
                prosumers[buyerQueue[i]].balance -= uint(actualTransferableEnergy) * energyPrice;
                prosumers[_prosumer].balance += uint(actualTransferableEnergy) * energyPrice;
                foundBuyer = true;
                if(prosumers[buyerQueue[i]].energyStatus == 0){
                    removeAtIndex(i,buyerQueue);
                }
                break;
            }
        }
        if(!foundBuyer){
            // if no buyer is found, the prosumer is added to the buyer queue
            Prosumer storage sender = prosumers[_prosumer];
            sender.energyStatus += energyUnits;
            sellerQueue.push(_prosumer);
        }
    }
//function to buy energy
    function buyEnergy(address _prosumer,int energyUnits) internal {

        bool foundSeller = false;

        //Iterating through seller queue to search for sellers
        for (uint i = 0; i < sellerQueue.length; i++) {
            if (prosumers[sellerQueue[i]].energyStatus >= -1 * energyUnits) {
                
                //Deduct energy from seller (adding here since energyUnits is a negative value)
                prosumers[sellerQueue[i]].energyStatus += energyUnits;
                
                // Update the balances of the buyer and the seller                
                prosumers[sellerQueue[i]].balance += uint(-energyUnits) * energyPrice;
                prosumers[_prosumer].balance -= uint(-energyUnits) * energyPrice;
                foundSeller = true;
                if(prosumers[sellerQueue[i]].energyStatus == 0){
                    removeAtIndex(i,sellerQueue);
                }
                break;
            }
        }
        if (!foundSeller) {
            // if no seller is found, the prosumer is added to the buyer queue
            Prosumer storage sender = prosumers[_prosumer];
            sender.energyStatus += energyUnits;
            buyerQueue.push(_prosumer);
        }
        
    }

}

contract MainContract is P2PEnergy{

    //Modifier to check if a prosumer is registered
    modifier prosumerIsRegistered(){
        require(prosumers[msg.sender].isRegistered == true,"The prosumer is not registered");
        _;
    }

    //Modifier to check whether a prosumer is not registered
    modifier notRegisteredProsumer(){
        require(prosumers[msg.sender].isRegistered == false, " The prosumer is already registered");
        _;
    }

    // Modifier to check whether the minimum amount of funds are present in prosumer's account in order to purchase energy units
    modifier checkFunds(int energy){
        uint energyUnits;
        if(energy < 0){
            energyUnits= uint(-energy);
            int requestsSent = prosumers[msg.sender].energyStatus;
            uint256 amountAvailable=prosumers[msg.sender].balance;
            require(amountAvailable >= energyUnits * energyPrice, " Insufficient balance in prosumer's account");

        //Checking past energy requests and seeing if the pending request amount exceeds the available balance in prosumer's balance
            uint256 amountAvailableRequest=prosumers[msg.sender].balance - uint(-requestsSent) * energyPrice;
            require(amountAvailableRequest >= energyUnits * energyPrice, "Pending request amount exceeds the available balance in prosumer's");
        }
        _;
    }

    // Function to register a prosumer
    function register() public notRegisteredProsumer{
        registerProsumer(msg.sender);
    }

    //Function to send a buyer or a seller request 
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
    function checkCurrentBalance() public prosumerIsRegistered view returns (uint balance) {
        return prosumers[msg.sender].balance;
    }

    //Function to deposit ethers in registered prosumer's account
     function deposit() public payable prosumerIsRegistered {
        require(msg.value > 0, "Deposit amount must be greater than zero.");
        prosumers[msg.sender].balance += msg.value;
    }

    //Function to withdraw ethers from a registered prosumer's account, provided the energyStatus is not in deficit.
    function withdraw() public prosumerIsRegistered {
            require(prosumers[msg.sender].energyStatus >= 0, "Cannot withdraw funds while energy deficit exists.");
            uint amount = prosumers[msg.sender].balance;
            require(amount > 0, "Insufficient balance.");
            prosumers[msg.sender].balance = 0;
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "Withdrawal failed.");
        }
}