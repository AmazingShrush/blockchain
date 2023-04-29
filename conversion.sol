pragma solidity ^0.8.6;

contract testConversion{
    uint public c;
    int public d;

    function setUint(int d) public {
        if(d < 0) {
           c= uint(-d);
        }
        else {
            c=uint(d);
        }
    }

   
}