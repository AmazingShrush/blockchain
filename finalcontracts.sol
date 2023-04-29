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
    function removeAtIndex(uint index, address[] storage array) internal {
        require(index < array.length, "Index out of bounds");
        for (uint i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
    }

    function sellEnergy(address _prosumer,int energyUnits) internal {
        bool foundBuyer = false;
        for(uint i=0; i<buyerQueue.length;i++){
            if(-1*prosumers[buyerQueue[i]].energyStatus <= energyUnits){
                prosumers[buyerQueue[i]].energyStatus += energyUnits;
                prosumers[buyerQueue[i]].balance -= uint(energyUnits) * 1 ether;
                prosumers[_prosumer].balance += uint(energyUnits) * 1 ether;
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
    function buyEnergy(address _prosumer,int energyUnits) public {

        bool foundSeller = false;
        for (uint i = 0; i < sellerQueue.length; i++) {
            if (prosumers[sellerQueue[i]].energyStatus >= -1 * energyUnits) {
                prosumers[sellerQueue[i]].energyStatus += energyUnits;
                prosumers[_prosumer].energyStatus -= energyUnits;
                prosumers[sellerQueue[i]].balance += uint(-energyUnits) * 1 ether;
                prosumers[_prosumer].balance -= uint(-energyUnits) * 1 ether;
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
        uint256 amountAvailableRequest=prosumers[msg.sender].balance - uint(-requestsSent) * 1 ether;
        require(amountAvailable >= energyUnits * 1 ether, " Insufficient balance in prosumer's account");
        require(amountAvailableRequest >= energyUnits * 1 ether, "Pending request amount exceeds the available balance in prosumer's account")
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