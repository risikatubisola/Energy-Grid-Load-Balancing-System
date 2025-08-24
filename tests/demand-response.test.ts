import { describe, it, expect, beforeEach } from "vitest"

// Mock contract state
let contractState = {
  programs: new Map(),
  participants: new Map(),
  events: new Map(),
  eventParticipation: new Map(),
  participantRewards: new Map(),
  totalPrograms: 0,
  totalEvents: 0,
  totalParticipants: 0,
}

const mockDemandResponseContract = {
  createProgram: (programId, name, programType, baseIncentive, performanceBonus, maxParticipants, sender) => {
    if (sender !== "CONTRACT-OWNER") {
      return { error: "ERR-NOT-AUTHORIZED" }
    }
    if (contractState.programs.has(programId)) {
      return { error: "ERR-PROGRAM-ALREADY-EXISTS" }
    }
    if (baseIncentive <= 0) {
      return { error: "ERR-INVALID-REDUCTION-TARGET" }
    }
    
    contractState.programs.set(programId, {
      name,
      programType,
      baseIncentive,
      performanceBonus,
      maxParticipants,
      currentParticipants: 0,
      status: "active",
      createdAt: Date.now(),
    })
    contractState.totalPrograms++
    return { success: programId }
  },
  
  joinProgram: (programId, meterId, maxReductionCapacity, baselineConsumption, sender) => {
    const program = contractState.programs.get(programId)
    if (!program) {
      return { error: "ERR-PROGRAM-NOT-FOUND" }
    }
    
    const participantKey = `${programId}-${sender}`
    if (contractState.participants.has(participantKey)) {
      return { error: "ERR-PARTICIPANT-ALREADY-EXISTS" }
    }
    
    if (program.currentParticipants >= program.maxParticipants) {
      return { error: "ERR-NOT-AUTHORIZED" }
    }
    
    if (maxReductionCapacity <= 0) {
      return { error: "ERR-INVALID-REDUCTION-TARGET" }
    }
    
    contractState.participants.set(participantKey, {
      meterId,
      maxReductionCapacity,
      baselineConsumption,
      participationScore: 100,
      totalRewards: 0,
      joinedAt: Date.now(),
      status: "active",
    })
    
    program.currentParticipants++
    contractState.totalParticipants++
    return { success: true }
  },
  
  createDemandResponseEvent: (
      eventId,
      programId,
      targetReduction,
      durationBlocks,
      incentiveRate,
      startBlock,
      sender,
  ) => {
    if (sender !== "CONTRACT-OWNER") {
      return { error: "ERR-NOT-AUTHORIZED" }
    }
    
    const program = contractState.programs.get(programId)
    if (!program) {
      return { error: "ERR-PROGRAM-NOT-FOUND" }
    }
    
    if (contractState.events.has(eventId)) {
      return { error: "ERR-EVENT-ALREADY-ACTIVE" }
    }
    
    if (targetReduction <= 0 || durationBlocks <= 0) {
      return { error: "ERR-INVALID-REDUCTION-TARGET" }
    }
    
    contractState.events.set(eventId, {
      programId,
      targetReduction,
      durationBlocks,
      incentiveRate,
      startBlock,
      endBlock: startBlock + durationBlocks,
      actualReduction: 0,
      participantsCount: 0,
      status: "scheduled",
      createdBy: sender,
    })
    
    contractState.totalEvents++
    return { success: eventId }
  },
  
  participateInEvent: (eventId, committedReduction, sender) => {
    const event = contractState.events.get(eventId)
    if (!event) {
      return { error: "ERR-EVENT-NOT-FOUND" }
    }
    
    const participantKey = `${event.programId}-${sender}`
    const participant = contractState.participants.get(participantKey)
    if (!participant) {
      return { error: "ERR-PARTICIPANT-NOT-FOUND" }
    }
    
    if (event.status !== "scheduled") {
      return { error: "ERR-NOT-AUTHORIZED" }
    }
    
    if (committedReduction > participant.maxReductionCapacity || committedReduction <= 0) {
      return { error: "ERR-INVALID-REDUCTION-TARGET" }
    }
    
    const participationKey = `${eventId}-${sender}`
    contractState.eventParticipation.set(participationKey, {
      committedReduction,
      actualReduction: 0,
      baselineConsumption: participant.baselineConsumption,
      rewardEarned: 0,
      participationConfirmed: true,
    })
    
    event.participantsCount++
    return { success: committedReduction }
  },
}

describe("Demand Response Contract", () => {
  beforeEach(() => {
    contractState = {
      programs: new Map(),
      participants: new Map(),
      events: new Map(),
      eventParticipation: new Map(),
      participantRewards: new Map(),
      totalPrograms: 0,
      totalEvents: 0,
      totalParticipants: 0,
    }
  })
  
  describe("Program Management", () => {
    it("should create a demand response program", () => {
      const result = mockDemandResponseContract.createProgram(
          "PROG001",
          "Residential DR",
          "residential",
          50,
          10,
          100,
          "CONTRACT-OWNER",
      )
      expect(result.success).toBe("PROG001")
      expect(contractState.totalPrograms).toBe(1)
    })
    
    it("should reject unauthorized program creation", () => {
      const result = mockDemandResponseContract.createProgram(
          "PROG001",
          "Residential DR",
          "residential",
          50,
          10,
          100,
          "unauthorized",
      )
      expect(result.error).toBe("ERR-NOT-AUTHORIZED")
    })
    
    it("should reject duplicate program creation", () => {
      mockDemandResponseContract.createProgram(
          "PROG001",
          "Residential DR",
          "residential",
          50,
          10,
          100,
          "CONTRACT-OWNER",
      )
      const result = mockDemandResponseContract.createProgram(
          "PROG001",
          "Commercial DR",
          "commercial",
          100,
          20,
          50,
          "CONTRACT-OWNER",
      )
      expect(result.error).toBe("ERR-PROGRAM-ALREADY-EXISTS")
    })
  })
  
  describe("Participant Management", () => {
    beforeEach(() => {
      mockDemandResponseContract.createProgram(
          "PROG001",
          "Residential DR",
          "residential",
          50,
          10,
          100,
          "CONTRACT-OWNER",
      )
    })
    
    it("should allow participant to join program", () => {
      const result = mockDemandResponseContract.joinProgram("PROG001", "METER001", 500, 1000, "user1")
      expect(result.success).toBe(true)
      expect(contractState.totalParticipants).toBe(1)
    })
    
    it("should reject joining non-existent program", () => {
      const result = mockDemandResponseContract.joinProgram("PROG999", "METER001", 500, 1000, "user1")
      expect(result.error).toBe("ERR-PROGRAM-NOT-FOUND")
    })
    
    it("should reject duplicate participation", () => {
      mockDemandResponseContract.joinProgram("PROG001", "METER001", 500, 1000, "user1")
      const result = mockDemandResponseContract.joinProgram("PROG001", "METER002", 300, 800, "user1")
      expect(result.error).toBe("ERR-PARTICIPANT-ALREADY-EXISTS")
    })
  })
  
  describe("Event Management", () => {
    beforeEach(() => {
      mockDemandResponseContract.createProgram(
          "PROG001",
          "Residential DR",
          "residential",
          50,
          10,
          100,
          "CONTRACT-OWNER",
      )
      mockDemandResponseContract.joinProgram("PROG001", "METER001", 500, 1000, "user1")
    })
    
    it("should create demand response event", () => {
      const result = mockDemandResponseContract.createDemandResponseEvent(
          "EVENT001",
          "PROG001",
          1000,
          12,
          75,
          1000,
          "CONTRACT-OWNER",
      )
      expect(result.success).toBe("EVENT001")
      expect(contractState.totalEvents).toBe(1)
    })
    
    it("should allow participant to join event", () => {
      mockDemandResponseContract.createDemandResponseEvent("EVENT001", "PROG001", 1000, 12, 75, 1000, "CONTRACT-OWNER")
      const result = mockDemandResponseContract.participateInEvent("EVENT001", 400, "user1")
      expect(result.success).toBe(400)
    })
    
    it("should reject participation with excessive reduction commitment", () => {
      mockDemandResponseContract.createDemandResponseEvent("EVENT001", "PROG001", 1000, 12, 75, 1000, "CONTRACT-OWNER")
      const result = mockDemandResponseContract.participateInEvent("EVENT001", 600, "user1") // More than max capacity of 500
      expect(result.error).toBe("ERR-INVALID-REDUCTION-TARGET")
    })
  })
})
