// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Marketplace {
    // Define an enum to represent the different states of a job
    enum JobState {
        New,
        Accepted,
        Solved
    }

    // Define a struct to represent a job
    struct Job {
        uint256 jobId;
        string description;
        string solutionLink;
        uint256 price;
        address owner;
        address payable freelancer;
        bool solved;
        uint256 timestamp;
        uint256 totalParts;
        uint256 partsSolved;
        uint256 partsAccepted;
        JobState state;
    }

    // Define a mapping to store the jobs that are available
    mapping(uint256 => Job) public jobs;
    uint256 numOfAvaliableJobs = 0;
    uint256 public counter = 0;

    event JobAccepted(address indexed freelancer, uint256 jobId);
    event PartAccepted(address indexed freelancer, uint256 jobId);
    event PartSubmitted(address indexed freelancer, uint256 jobId);
    event PartRejected(address indexed freelancer, uint256 jobId);

    // Define a function to publish a new job
    function publishJob(
        string memory description,
        uint256 price,
        uint256 totalParts
    ) public payable {
        // Check that the price is greater than zero
        require(price > 0, "The price must be greater than zero.");

        // Check that the totalParts is greater than zero
        require(totalParts > 0, "The totalParts must be greater than zero.");

        // Check that the caller of the function is not the zero address
        require(
            msg.sender != address(0),
            "The contract cannot accept transactions from the zero address."
        );

        // Check that the amount of Ether sent with the transaction is equal to the price of the job
        require(
            msg.value >= price,
            "The amount of Ether sent must be more then the price of the job."
        );

        // Create a new job and store it in the jobs mapping
        uint256 jobId = counter++;
        numOfAvaliableJobs++;
        jobs[jobId] = Job(
            jobId,
            description,
            "",
            price,
            msg.sender,
            payable(address(0)),
            false,
            block.timestamp,
            totalParts,
            0,
            0,
            JobState.New
        );
    }

    // Define a function to accept a job
    
    function acceptJob(uint256 jobId) public {
        // Check that the jobId exists in the jobs mapping
        //require(jobs[jobId].description != "", "The job does not exist.");

        // Retrieve the job from the jobs mapping
        Job storage job = jobs[jobId];

        // Check that the job has not already been solved
        require(
            job.state != JobState.Solved,
            "The job has already been solved."
        );

        // Check that the caller of the function is not the owner of the job
        require(
            msg.sender != job.owner,
            "The owner of the job cannot accept the job themselves."
        );

        // Set the freelancer for the job to the current caller
        job.freelancer = payable(msg.sender);

        // Update the job state to Accepted
        job.state = JobState.Accepted;

        // Update the job in the jobs mapping
        jobs[jobId] = job;

        // Emit an event to indicate that the freelancer has successfully accepted the job
        emit JobAccepted(msg.sender, jobId);
    }

    // Define a function to submit a solved part of a job
    function submitSolvedPart(uint256 jobId, string memory link) public {
        // Fetch the job from the job mapping
        Job storage job = jobs[jobId];

        // Check that the job has not already been solved
        require(
            job.state != JobState.Solved,
            "The job has already been solved."
        );

        // Check that the caller of the function is the freelancer who accepted the job
        require(
            msg.sender == job.freelancer,
            "Only the freelancer who accepted the job can submit solved parts."
        );

        require(
            job.partsSolved == job.partsAccepted,
            "Cannot submit while you have a pending part."
        );

        if(job.partsSolved == 0){
            job.solutionLink = link;
        }

        // Update the number of solved parts for the job
        job.partsSolved++;

        // Check if all parts of the job have been solved
        if (job.partsSolved == job.totalParts) {
            // If all parts have been solved, mark the job as solved and update its state
            job.solved = true;
            job.state = JobState.Solved;
            numOfAvaliableJobs--;
        }

        // Update the job in the jobs mapping
        jobs[jobId] = job;

        // Emit an event to indicate that the freelancer has successfully submitted a solved part of the job
        emit PartSubmitted(msg.sender, jobId);
    }

    // Define a function to accept a solved part of a job
    function acceptSolvedPart(uint256 jobId) public {
        // Check that the jobId exists in the jobs mapping
        //require(jobs[jobId].description != "", "The job does not exist.");

        // Fetch the job from the job mapping
        Job storage job = jobs[jobId];

        // Check that the caller of the function is the owner of the job
        require(
            msg.sender == job.owner,
            "Only the owner of the job can accept solved parts."
        );

        // Check that there are submitted parts that can be accepted
        require(
            job.partsSolved > job.partsAccepted,
            "There are no submitted parts that can be accepted."
        );

        // Calculate the amount to be paid to the freelancer
        uint256 payment = (job.partsSolved - job.partsAccepted) *
            (job.price / job.totalParts);

        // Pay the freelancer for the submitted and accepted parts
        job.freelancer.transfer(payment);

        // Update the number of accepted parts for the job
        job.partsAccepted = job.partsSolved;

        // Check if all parts of the job have been accepted
        if (job.partsAccepted == job.totalParts) {
            // If all parts have been accepted, mark the job as solved and update its state
            job.solved = true;
            job.state = JobState.Solved;
        }

        // Update the job in the jobs mapping
        jobs[jobId] = job;

        // Emit an event to indicate that the owner has successfully accepted a solved part of the job
        emit PartAccepted(msg.sender, jobId);
    }

    function rejectSolvedPart(uint256 jobId) public {

        // Check that the jobId exists in the jobs mapping
        //require(jobs[jobId].description != "", "The job does not exist.");

        // Fetch the job from the job mapping
        Job storage job = jobs[jobId];

        // Check that the caller of the function is the owner of the job
        require(
            msg.sender == job.owner,
            "Only the owner of the job can reject solved parts."
        );

        // Check that there are submitted parts that can be rejected
        require(
            job.partsSolved > job.partsAccepted,
            "There are no submitted parts that can be rejected."
        );

        // Update the number of accepted parts for the job
        job.partsSolved = job.partsAccepted;

        if(job.partsSolved == 0){
            job.solutionLink = "";
        }

        // Update the job in the jobs mapping
        jobs[jobId] = job;

        // Emit an event to indicate that the owner has successfully rejected a solved part of the job
        emit PartRejected(msg.sender, jobId);
    }

    function browseJobs() public view returns (Job[] memory) {
        // Create an array to store the IDs of the available jobs
        Job[] memory availableJobs = new Job[](numOfAvaliableJobs);

        // Iterate over all the jobs in the jobs mapping
        uint256 count = 0;
        for (uint256 i = 0; i < counter; i++) {
            // Check if the job is available (not solved and with a description)
            if (jobs[i].state == JobState.New) {
                // && jobs[i].description != ""
                // If the job is available, add its ID to the array of available jobs
                availableJobs[count] = jobs[i];
                count++;
            }
        }

        // Return the array of available jobs
        return availableJobs;
    }
}
