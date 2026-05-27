pragma circom 2.1.0;

include "../node_modules/circomlib/circuits/poseidon.circom";

template ProofOfReserves(N) {
    signal input positions[N];
    signal input salt;
    
    signal input totalAssets;
    signal input timestamp;
    
    signal output commitment;


    signal positionSum[N];
    positionSum[0] <== positions[0];
    
    for (var i = 1; i < N; i++) {
        positionSum[i] <== positionSum[i-1] + positions[i];
    }
    
    positionSum[N-1] === totalAssets;

    component hasher = Poseidon(N + 1);
    
    for (var i = 0; i < N; i++) {
        hasher.inputs[i] <== positions[i];
    }
    hasher.inputs[N] <== salt;
    
    commitment <== hasher.out;
    
    signal timestampSquare;
    timestampSquare <== timestamp * timestamp;
}

component main {public [totalAssets, timestamp]} = ProofOfReserves(10);