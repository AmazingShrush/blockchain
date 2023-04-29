pragma solidity ^0.8.0;

contract P2PEnergy{
    struct Prosumer{
        address ID;
        int energyStatus;
        uint256 balance;
        bool isRegistered;
    }

    mapping(address => Prosumer)public prosumers;
    address[] public buyerQueue;
    address[] public sellerQueue;
    function registerProsumer(address _prosumerAddress) internal{
        prosumers[_prosumerAddress] = Prosumer(_prosumerAddress,0,0,true);
    }

    //function to sell energy
    function sellEnergy(address _prosumer,int energyUnits) internal {
        bool foundBuyer = false;
        for(uint i=0; i<buyerQueue.length;i++){
            if(-1*prosumers[buyerQueue[i]].energyStatus <= energyUnits){
                prosumers[buyerQueue[i]].energyStatus += energyUnits;
                prosumers[buyerQueue[i]].balance -= uint(energyUnits) * 1 ether;
                prosumers[_prosumer].balance += uint(energyUnits) * 1 ether;
                foundBuyer = true;
                break;
            }
        }
        if(!foundBuyer){
            Prosumer storage sender = prosumers[_prosumer];
            sender.energyStatus += energyUnits;
            sellerQueue.push(_prosumer);
        }
        // for (uint i = 0; i < buyerQueue.length; i++) {
        //     if (prosumers[buyerQueue[i]].energyStatus <= energyUnits) {
        //         prosumers[sellerQueue[i]].energyStatus += energyUnits;
        //         prosumers[buyerQueue[i]].energyStatus -= energyUnits;
        //         prosumers[_prosumer].balance += energyUnits * 1 ether;
        //         foundBuyer = true;
        //         break;
        //     }
        // }
        // if (!foundBuyer) {
        //    Prosumer storage sender = prosumers[_prosumer];
        //     sender.energyStatus += energyUnits;
        //     sellerQueue.push(_prosumer);
        // }
        
    }
//function to buy energy
    function buyEnergy(address _prosumer,int energyUnits) public {

        bool foundSeller = false;
        for(uint i=0;i< sellerQueue.length;i++){
            if(prosumers[sellerQueue[i]].energyStatus >= -1*energyUnits){
                prosumers[sellerQueue[i]].energyStatus += energyUnits;
                prosumers[sellerQueue[i]].balance += uint(-energyUnits) * 1 ether;
                prosumers[_prosumer].balance -= uint(-energyUnits) * 1 ether;
                foundSeller = true;
                break;
            }

            if(!foundSeller){
                 Prosumer storage sender = prosumers[_prosumer];
                 sender.energyStatus += energyUnits;
                 buyerQueue.push(_prosumer);
            }
        }
        // for (uint i = 0; i < sellerQueue.length; i++) {
        //     if (prosumers[sellerQueue[i]].energyStatus >= energyUnits) {
        //         prosumers[sellerQueue[i]].energyStatus -= energyUnits;
        //         prosumers[_prosumer].energyStatus += energyUnits;
        //         prosumers[sellerQueue[i]].balance += energyUnits * 1 ether;
        //         prosumers[_prosumer].balance -= energyUnits * 1 ether;
        //         foundSeller = true;
        //         break;
        //     }
        // }
        // if (!foundSeller) {
        //     Prosumer storage sender = prosumers[_prosumer];
        //     sender.energyStatus += energyUnits;
        //     buyerQueue.push(_prosumer);
        // }
        
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
        uint256 amountAvailable=prosumers[msg.sender].balance;
        require(amountAvailable >= energyUnits * 1 ether, " Insufficient balance in prosumer's account");
        }
        _;
    }

    function register() public notRegisteredProsumer{
        registerProsumer(msg.sender);
    }

    function sendEnergyRequest(int energy) public prosumerIsRegistered checkFunds(energy){
        //  uint energyUnits;
        // if(energy < 0) {
        //    energyUnits= uint(-energy);
        // }
        // else {
        //     energyUnits=uint(energy);
        // }
       
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