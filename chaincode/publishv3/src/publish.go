package main

import (
    "encoding/json"
    "fmt"
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing a simple key-value pair
type SmartContract struct {
    contractapi.Contract
}

// InitLedger initializes the chaincode state with some default values
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
    // Add initial values here if needed
    return nil
}

func (s *SmartContract) ResourceExists(ctx contractapi.TransactionContextInterface, pid string) (bool, error) {
    data, err := ctx.GetStub().GetState(pid)
    if err != nil {
        return false, fmt.Errorf("failed to read state: %v", err)
    }
    return data != nil, nil
}

func (s *SmartContract) HLF_CreateProv(ctx contractapi.TransactionContextInterface, pid string, uri string, hash string, timestamp string, ownersJSON string) error {
    // Check if resource already exists
    exists, err := s.ResourceExists(ctx, pid)
    if err != nil {
        return fmt.Errorf("failed to check if resource exists: %v", err)
    }
    if exists {
        return fmt.Errorf("resource with PID '%s' already exists", pid)
    }

    var owners []string
    err = json.Unmarshal([]byte(ownersJSON), &owners)
    if err != nil {
        return fmt.Errorf("failed to parse owners list: %v", err)
    }
    // Get client identity
    clientID, err := ctx.GetClientIdentity().GetID()
    if err != nil {
        return fmt.Errorf("failed to get client identity: %v", err)
    }

    // Add client ID to owners list
    fullOwners := append(owners, clientID)

    // Create resource object
    resource := map[string]interface{}{
        "uri":       uri,
        "hash":      hash,
        "timestamp": timestamp,
        "version":   0,
        "owners":    fullOwners,
    }

    // Marshal and store
    resourceJSON, _ := json.Marshal(resource)
    err = ctx.GetStub().SetEvent("ResourceCreated", resourceJSON)
    if err != nil {
        return fmt.Errorf("failed to serialize resource: %v", err)
    }

    return ctx.GetStub().PutState(pid, resourceJSON)
}


// Get retrieves a value for a given key
func (s *SmartContract) HLF_ReadProv(ctx contractapi.TransactionContextInterface, key string) (string, error) {
    value, err := ctx.GetStub().GetState(key)
    if err != nil {
        return "", fmt.Errorf("failed to read from world state: %v", err)
    }
    if value == nil {
        return "", fmt.Errorf("key '%s' does not exist in the world state", key)
    }
    return string(value), nil
}

// main function starts up the chaincode in the container
func main() {
    chaincode := new(SmartContract)
    cc, err := contractapi.NewChaincode(chaincode)
    if err != nil {
        fmt.Printf("Error creating chaincode: %s", err.Error())
        return
    }

    if err := cc.Start(); err != nil {
        fmt.Printf("Error starting chaincode: %s", err.Error())
    }
}
