-- =============================================================================
-- SCHOOL MANAGEMENT SAAS - COMPLETE DATABASE SCHEMA V3.0
-- =============================================================================
-- Author: Deepak Kumar Jha
-- Review Date: December 2025
-- Description: Multi-tenant SaaS platform for school management
-- Changes from V2: Added critical enhancements (promotions, leaves, exam scheduling, 
--                   conduct records, assignments, multi-role support, soft deletes)
-- Total Tables: 44 (32 original + 12 new enhancements)
-- =============================================================================

-- =============================================================================
-- MODULE 1: PLATFORM / TENANT (Foundations)
-- =============================================================================

-- 1. Schools (Tenant)
CREATE TABLE Schools (
    SchoolId INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Code NVARCHAR(50) NOT NULL, -- Unique Code for Subdomains/Login
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_Schools_Code UNIQUE (Code)
);

-- 2. Branches
CREATE TABLE Branches (
    BranchId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    Code NVARCHAR(50) NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    DeletedAt DATETIME2 NULL, -- Soft delete support
    CONSTRAINT FK_Branches_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId)
);

-- 3. Academic Years (CRITICAL TABLE)
-- Handles year transitions (e.g., 2024-2025 vs 2025-2026)
CREATE TABLE AcademicYears (
    YearId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    Name NVARCHAR(50) NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    IsCurrent BIT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_AcademicYears_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId)
);

-- 4. School Configurations (NEW)
-- For school-specific settings without schema changes
CREATE TABLE SchoolConfigurations (
    ConfigId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    ConfigKey NVARCHAR(100) NOT NULL,
    ConfigValue NVARCHAR(MAX),
    DataType NVARCHAR(20), -- 'string', 'int', 'boolean', 'json'
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    UpdatedAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_SC_School FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT UQ_Config_Key UNIQUE (SchoolId, ConfigKey)
);

-- =============================================================================
-- MODULE 2: AUTH & RBAC
-- =============================================================================

-- 5. Roles
CREATE TABLE Roles (
    RoleId INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(200),
    IsSystem BIT DEFAULT 0, -- Cannot delete system roles (Admin, Teacher, etc.)
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT SYSDATETIME()
);

-- 6. Permissions
CREATE TABLE Permissions (
    PermissionId INT IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(100) NOT NULL UNIQUE, -- e.g., 'STUDENT_CREATE'
    Description NVARCHAR(200),
    Category NVARCHAR(50), -- 'Student', 'Finance', 'Academic'
    IsActive BIT NOT NULL DEFAULT 1
);

-- 7. RolePermissions (Mapping)
CREATE TABLE RolePermissions (
    RoleId INT NOT NULL,
    PermissionId INT NOT NULL,
    CONSTRAINT PK_RolePermissions PRIMARY KEY (RoleId, PermissionId),
    CONSTRAINT FK_RP_Roles FOREIGN KEY (RoleId) REFERENCES Roles(RoleId),
    CONSTRAINT FK_RP_Permissions FOREIGN KEY (PermissionId) REFERENCES Permissions(PermissionId)
);

-- 8. Users (Global Identity)
CREATE TABLE Users (
    UserId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    BranchId INT NULL, -- Optional: If user is restricted to one branch
    Username NVARCHAR(100) NOT NULL,
    PasswordHash NVARCHAR(500) NOT NULL,
    Salt NVARCHAR(100) NULL, -- Added for security
    RoleId INT NOT NULL, -- Primary Role (will be deprecated, use UserRoles)
    IsApproved BIT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    LastLoginAt DATETIME2 NULL,
    DeletedAt DATETIME2 NULL, -- Soft delete
    CONSTRAINT FK_Users_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_Users_Branches FOREIGN KEY (BranchId) REFERENCES Branches(BranchId),
    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES Roles(RoleId),
    CONSTRAINT UQ_Users_Username_School UNIQUE (Username, SchoolId)
);

-- 9. UserRoles (NEW - Multi-Role Support)
-- Replaces single RoleId in Users table
CREATE TABLE UserRoles (
    UserRoleId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    RoleId INT NOT NULL,
    BranchId INT NULL, -- Role scoped to specific branch (optional)
    AssignedAt DATETIME2 DEFAULT SYSDATETIME(),
    AssignedBy INT NOT NULL,
    DeletedAt DATETIME2 NULL,
    CONSTRAINT UQ_UserRoles_Unique UNIQUE (UserId, RoleId, BranchId),
    CONSTRAINT FK_UR_User FOREIGN KEY (UserId) REFERENCES Users(UserId),
    CONSTRAINT FK_UR_Role FOREIGN KEY (RoleId) REFERENCES Roles(RoleId),
    CONSTRAINT FK_UR_Branch FOREIGN KEY (BranchId) REFERENCES Branches(BranchId),
    CONSTRAINT FK_UR_AssignedBy FOREIGN KEY (AssignedBy) REFERENCES Users(UserId)
);

-- 10. User Sessions (NEW)
-- Security feature for multi-device logins
CREATE TABLE UserSessions (
    SessionId BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    SessionToken NVARCHAR(500) NOT NULL,
    DeviceType NVARCHAR(50), -- 'Mobile', 'Web', 'Tablet'
    IPAddress NVARCHAR(45), -- IPv6 support
    UserAgent NVARCHAR(500),
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    LastActivityAt DATETIME2,
    ExpiresAt DATETIME2,
    CONSTRAINT FK_US_User FOREIGN KEY (UserId) REFERENCES Users(UserId)
);

-- =============================================================================
-- MODULE 3: USER BUSINESS DOMAIN
-- =============================================================================

-- 11. UserProfiles (Extended details)
CREATE TABLE UserProfiles (
    UserId INT PRIMARY KEY,
    FirstName NVARCHAR(100),
    LastName NVARCHAR(100),
    Email NVARCHAR(200),
    Phone NVARCHAR(20),
    Address NVARCHAR(500),
    DateOfBirth DATE,
    Gender NVARCHAR(10),
    ProfilePictureUrl NVARCHAR(MAX),
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    UpdatedAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_UserProfiles_Users FOREIGN KEY (UserId) REFERENCES Users(UserId)
);

-- 12. Students (Identity - Static Data)
CREATE TABLE Students (
    StudentId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    SchoolId INT NOT NULL,
    AdmissionNo NVARCHAR(50) NOT NULL, -- Static ID
    JoiningDate DATE NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_Students_Users FOREIGN KEY (UserId) REFERENCES Users(UserId),
    CONSTRAINT FK_Students_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT UQ_Students_AdmissionNo UNIQUE (SchoolId, AdmissionNo)
);

-- 13. Teachers
CREATE TABLE Teachers (
    TeacherId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    SchoolId INT NOT NULL,
    BranchId INT NOT NULL,
    EmployeeCode NVARCHAR(50),
    Qualification NVARCHAR(200),
    Specialization NVARCHAR(200),
    JoiningDate DATE,
    IsActive BIT NOT NULL DEFAULT 1,
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_Teachers_Users FOREIGN KEY (UserId) REFERENCES Users(UserId),
    CONSTRAINT FK_Teachers_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_Teachers_Branches FOREIGN KEY (BranchId) REFERENCES Branches(BranchId)
);

-- 14. Staff (Non-teaching)
CREATE TABLE Staff (
    StaffId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    SchoolId INT NOT NULL,
    BranchId INT NOT NULL,
    Designation NVARCHAR(100),
    Department NVARCHAR(100),
    IsActive BIT NOT NULL DEFAULT 1,
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_Staff_Users FOREIGN KEY (UserId) REFERENCES Users(UserId),
    CONSTRAINT FK_Staff_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_Staff_Branches FOREIGN KEY (BranchId) REFERENCES Branches(BranchId)
);

-- 15. Parents
CREATE TABLE Parents (
    ParentId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    SchoolId INT NOT NULL,
    PrimaryParentId INT NULL, -- Link to main account for billing consolidation
    Occupation NVARCHAR(100),
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_Parents_Users FOREIGN KEY (UserId) REFERENCES Users(UserId),
    CONSTRAINT FK_Parents_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_Parents_Primary FOREIGN KEY (PrimaryParentId) REFERENCES Parents(ParentId)
);

-- 16. Parent-Student Mapping
CREATE TABLE ParentStudents (
    ParentId INT NOT NULL,
    StudentId INT NOT NULL,
    Relationship NVARCHAR(50), -- Father, Mother, Guardian
    IsPrimaryContact BIT DEFAULT 0,
    CONSTRAINT PK_ParentStudents PRIMARY KEY (ParentId, StudentId),
    CONSTRAINT FK_PS_Parents FOREIGN KEY (ParentId) REFERENCES Parents(ParentId),
    CONSTRAINT FK_PS_Students FOREIGN KEY (StudentId) REFERENCES Students(StudentId)
);

-- =============================================================================
-- MODULE 4: ACADEMIC STRUCTURE
-- =============================================================================

-- 17. Classes
CREATE TABLE Classes (
    ClassId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    BranchId INT NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    Description NVARCHAR(200),
    Sequence INT, -- For ordering (Class 1, 2, 3...)
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_Classes_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_Classes_Branches FOREIGN KEY (BranchId) REFERENCES Branches(BranchId)
);

-- 18. Sections
CREATE TABLE Sections (
    SectionId INT IDENTITY(1,1) PRIMARY KEY,
    ClassId INT NOT NULL,
    Name NVARCHAR(50) NOT NULL,
    MaxCapacity INT,
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_Sections_Classes FOREIGN KEY (ClassId) REFERENCES Classes(ClassId)
);

-- 19. Student Enrollments (The "Session" Link)
-- This connects a Student to a Class for a specific Year
CREATE TABLE StudentEnrollments (
    EnrollmentId INT IDENTITY(1,1) PRIMARY KEY,
    StudentId INT NOT NULL,
    AcademicYearId INT NOT NULL,
    ClassId INT NOT NULL,
    SectionId INT NOT NULL,
    RollNumber NVARCHAR(20),
    Status TINYINT DEFAULT 1, -- 1=Active, 2=Transferred, 3=Left
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    TransferredAt DATETIME2 NULL,
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_SE_Students FOREIGN KEY (StudentId) REFERENCES Students(StudentId),
    CONSTRAINT FK_SE_Years FOREIGN KEY (AcademicYearId) REFERENCES AcademicYears(YearId),
    CONSTRAINT FK_SE_Classes FOREIGN KEY (ClassId) REFERENCES Classes(ClassId),
    CONSTRAINT FK_SE_Sections FOREIGN KEY (SectionId) REFERENCES Sections(SectionId)
);

-- 20. Student Progressions (NEW - Annual Promotions)
-- CRITICAL: Handle Class 5 → Class 6 promotions
CREATE TABLE StudentProgressions (
    ProgressionId BIGINT IDENTITY(1,1) PRIMARY KEY,
    StudentEnrollmentId INT NOT NULL,
    FromAcademicYearId INT NOT NULL,
    ToAcademicYearId INT NOT NULL,
    FromClassId INT NOT NULL,
    ToClassId INT NOT NULL,
    PromotionStatus TINYINT NOT NULL DEFAULT 1, -- 1=Promoted, 2=Detained, 3=Withdrawn
    PromotionDate DATE DEFAULT CAST(SYSDATETIME() AS DATE),
    Remarks NVARCHAR(500),
    PromotedBy INT NOT NULL,
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_SP_Enrollment FOREIGN KEY (StudentEnrollmentId) 
        REFERENCES StudentEnrollments(EnrollmentId),
    CONSTRAINT FK_SP_FromYear FOREIGN KEY (FromAcademicYearId) 
        REFERENCES AcademicYears(YearId),
    CONSTRAINT FK_SP_ToYear FOREIGN KEY (ToAcademicYearId) 
        REFERENCES AcademicYears(YearId),
    CONSTRAINT FK_SP_FromClass FOREIGN KEY (FromClassId) 
        REFERENCES Classes(ClassId),
    CONSTRAINT FK_SP_ToClass FOREIGN KEY (ToClassId) 
        REFERENCES Classes(ClassId),
    CONSTRAINT FK_SP_PromotedBy FOREIGN KEY (PromotedBy) 
        REFERENCES Users(UserId)
);

-- 21. Subjects
CREATE TABLE Subjects (
    SubjectId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    Code NVARCHAR(20),
    Description NVARCHAR(200),
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_Subjects_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId)
);

-- 22. ClassSubjects (Teacher Assignment)
-- Added AcademicYearId because teacher assignments change every year!
CREATE TABLE ClassSubjects (
    ClassSubjectId INT IDENTITY(1,1) PRIMARY KEY,
    AcademicYearId INT NOT NULL,
    ClassId INT NOT NULL,
    SectionId INT NULL, -- NULL means applies to all sections, specific ID means override
    SubjectId INT NOT NULL,
    TeacherId INT NOT NULL,
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_CS_Year FOREIGN KEY (AcademicYearId) REFERENCES AcademicYears(YearId),
    CONSTRAINT FK_CS_Classes FOREIGN KEY (ClassId) REFERENCES Classes(ClassId),
    CONSTRAINT FK_CS_Subjects FOREIGN KEY (SubjectId) REFERENCES Subjects(SubjectId),
    CONSTRAINT FK_CS_Teachers FOREIGN KEY (TeacherId) REFERENCES Teachers(TeacherId)
);

-- 23. Timetable
CREATE TABLE Timetable (
    TimetableId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    AcademicYearId INT NOT NULL,
    ClassId INT NOT NULL,
    SectionId INT NOT NULL,
    SubjectId INT NOT NULL,
    TeacherId INT NULL,
    DayOfWeek TINYINT NOT NULL, -- 1=Mon, 2=Tue...
    PeriodNumber INT NOT NULL,
    StartTime TIME(0) NOT NULL,
    EndTime TIME(0) NOT NULL,
    RoomNumber NVARCHAR(50) NULL,
    IsLabPeriod BIT DEFAULT 0,
    CONSTRAINT FK_TT_School FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_TT_Year FOREIGN KEY (AcademicYearId) REFERENCES AcademicYears(YearId),
    CONSTRAINT FK_TT_Section FOREIGN KEY (SectionId) REFERENCES Sections(SectionId),
    CONSTRAINT FK_TT_Subject FOREIGN KEY (SubjectId) REFERENCES Subjects(SubjectId),
    CONSTRAINT CK_TT_Time CHECK (EndTime > StartTime)
);

-- =============================================================================
-- MODULE 5: ACADEMIC OPERATIONS
-- =============================================================================

-- 24. Attendance
-- Changed StudentId -> StudentEnrollmentId to track "Class 5" attendance vs "Class 6"
CREATE TABLE Attendance (
    AttendanceId BIGINT IDENTITY(1,1) PRIMARY KEY,
    StudentEnrollmentId INT NOT NULL,
    AcademicYearId INT NOT NULL, -- NEW: Explicit year tracking
    Date DATE NOT NULL,
    Status TINYINT NOT NULL, -- 1=Present, 2=Absent, 3=Late, 4=On Leave
    Remarks NVARCHAR(200),
    MarkedBy INT NOT NULL,
    AddedAt DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedAt DATETIME2 NULL,
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_Attendance_Enrollment FOREIGN KEY (StudentEnrollmentId) 
        REFERENCES StudentEnrollments(EnrollmentId),
    CONSTRAINT FK_Attendance_Year FOREIGN KEY (AcademicYearId) 
        REFERENCES AcademicYears(YearId),
    CONSTRAINT FK_Attendance_Users FOREIGN KEY (MarkedBy) REFERENCES Users(UserId)
);

-- 25. Leave Types (NEW)
CREATE TABLE LeaveTypes (
    LeaveTypeId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    Name NVARCHAR(50) NOT NULL,
    Description NVARCHAR(200),
    IsApprovalRequired BIT DEFAULT 0,
    MaxDaysPerYear INT DEFAULT NULL, -- NULL = Unlimited
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_LT_School FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT UQ_LeaveType_School UNIQUE (SchoolId, Name)
);

-- 26. Student Leaves (NEW)
CREATE TABLE StudentLeaves (
    LeaveId BIGINT IDENTITY(1,1) PRIMARY KEY,
    StudentEnrollmentId INT NOT NULL,
    LeaveTypeId INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    Reason NVARCHAR(500),
    ApprovedBy INT NULL,
    Status TINYINT DEFAULT 0, -- 0=Pending, 1=Approved, 2=Rejected
    RejectionReason NVARCHAR(500),
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_SL_Student FOREIGN KEY (StudentEnrollmentId) 
        REFERENCES StudentEnrollments(EnrollmentId),
    CONSTRAINT FK_SL_Type FOREIGN KEY (LeaveTypeId) 
        REFERENCES LeaveTypes(LeaveTypeId),
    CONSTRAINT FK_SL_Approver FOREIGN KEY (ApprovedBy) 
        REFERENCES Users(UserId),
    CONSTRAINT CK_SL_Dates CHECK (EndDate >= StartDate)
);

-- 27. Teacher Leaves (NEW)
CREATE TABLE TeacherLeaves (
    LeaveId BIGINT IDENTITY(1,1) PRIMARY KEY,
    TeacherId INT NOT NULL,
    LeaveTypeId INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    Reason NVARCHAR(500),
    ApprovedBy INT NULL,
    Status TINYINT DEFAULT 0,
    RejectionReason NVARCHAR(500),
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_TL_Teacher FOREIGN KEY (TeacherId) REFERENCES Teachers(TeacherId),
    CONSTRAINT FK_TL_Type FOREIGN KEY (LeaveTypeId) 
        REFERENCES LeaveTypes(LeaveTypeId),
    CONSTRAINT FK_TL_Approver FOREIGN KEY (ApprovedBy) 
        REFERENCES Users(UserId),
    CONSTRAINT CK_TL_Dates CHECK (EndDate >= StartDate)
);

-- 28. Student Conduct Records (NEW)
-- CRITICAL: Track behavior, achievements, disciplinary actions
CREATE TABLE StudentConductRecords (
    RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
    StudentEnrollmentId INT NOT NULL,
    RecordType NVARCHAR(50) NOT NULL, -- 'Positive', 'Disciplinary', 'Achievement'
    Title NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX),
    RecordedBy INT NOT NULL,
    RecordedAt DATETIME2 DEFAULT SYSDATETIME(),
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_SCR_Enrollment FOREIGN KEY (StudentEnrollmentId) 
        REFERENCES StudentEnrollments(EnrollmentId),
    CONSTRAINT FK_SCR_User FOREIGN KEY (RecordedBy) REFERENCES Users(UserId)
);

-- 29. Exams (Updated with Year)
CREATE TABLE Exams (
    ExamId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    AcademicYearId INT NOT NULL,
    BranchId INT NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    StartDate DATE,
    EndDate DATE,
    IsPublished BIT DEFAULT 0,
    CONSTRAINT FK_Exams_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_Exams_Years FOREIGN KEY (AcademicYearId) REFERENCES AcademicYears(YearId),
    CONSTRAINT FK_Exams_Branches FOREIGN KEY (BranchId) REFERENCES Branches(BranchId)
);

-- 30. ExamSubjects
CREATE TABLE ExamSubjects (
    ExamSubjectId INT IDENTITY(1,1) PRIMARY KEY,
    ExamId INT NOT NULL,
    SubjectId INT NOT NULL,
    MaxMarks INT NOT NULL,
    PassMarks INT NOT NULL,
    ExamDate DATETIME2,
    CONSTRAINT FK_ES_Exams FOREIGN KEY (ExamId) REFERENCES Exams(ExamId),
    CONSTRAINT FK_ES_Subjects FOREIGN KEY (SubjectId) REFERENCES Subjects(SubjectId)
);

-- 31. Exam Schedules (NEW)
CREATE TABLE ExamSchedules (
    ScheduleId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ExamSubjectId INT NOT NULL,
    ExamCenterLocation NVARCHAR(100), -- e.g., "Room 101", "Lab A"
    ExamDate DATE NOT NULL,
    StartTime TIME(0) NOT NULL,
    EndTime TIME(0) NOT NULL,
    MaxCapacity INT,
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_ES_ExamSubject FOREIGN KEY (ExamSubjectId) 
        REFERENCES ExamSubjects(ExamSubjectId),
    CONSTRAINT CK_ES_Time CHECK (EndTime > StartTime)
);

-- 32. Hall Tickets (NEW)
CREATE TABLE HallTickets (
    TicketId BIGINT IDENTITY(1,1) PRIMARY KEY,
    StudentEnrollmentId INT NOT NULL,
    ExamScheduleId BIGINT NOT NULL,
    SeatNumber NVARCHAR(20),
    RollNumber NVARCHAR(20),
    InvigilatorId INT NULL,
    GeneratedAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_HT_Student FOREIGN KEY (StudentEnrollmentId) 
        REFERENCES StudentEnrollments(EnrollmentId),
    CONSTRAINT FK_HT_Schedule FOREIGN KEY (ExamScheduleId) 
        REFERENCES ExamSchedules(ScheduleId),
    CONSTRAINT FK_HT_Invigilator FOREIGN KEY (InvigilatorId) 
        REFERENCES Users(UserId)
);

-- 33. Results
CREATE TABLE Results (
    ResultId INT IDENTITY(1,1) PRIMARY KEY,
    StudentEnrollmentId INT NOT NULL, -- Changed from StudentId to EnrollmentId
    ExamSubjectId INT NOT NULL,
    MarksObtained DECIMAL(5,2) NOT NULL,
    Remarks NVARCHAR(200),
    EnteredBy INT NOT NULL,
    EnteredAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Results_Student FOREIGN KEY (StudentEnrollmentId) 
        REFERENCES StudentEnrollments(EnrollmentId),
    CONSTRAINT FK_Results_ExamSubject FOREIGN KEY (ExamSubjectId) 
        REFERENCES ExamSubjects(ExamSubjectId),
    CONSTRAINT FK_Results_EnteredBy FOREIGN KEY (EnteredBy) REFERENCES Users(UserId)
);

-- =============================================================================
-- MODULE 6: ASSIGNMENTS & HOMEWORK (NEW)
-- =============================================================================

-- 34. Assignments (NEW)
CREATE TABLE Assignments (
    AssignmentId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ClassSubjectId INT NOT NULL,
    Title NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX),
    DueDate DATE,
    MaxMarks INT,
    CreatedBy INT NOT NULL,
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_A_ClassSubject FOREIGN KEY (ClassSubjectId) 
        REFERENCES ClassSubjects(ClassSubjectId),
    CONSTRAINT FK_A_Teacher FOREIGN KEY (CreatedBy) REFERENCES Users(UserId)
);

-- 35. Student Assignment Submissions (NEW)
CREATE TABLE StudentAssignmentSubmissions (
    SubmissionId BIGINT IDENTITY(1,1) PRIMARY KEY,
    AssignmentId BIGINT NOT NULL,
    StudentEnrollmentId INT NOT NULL,
    SubmittedAt DATETIME2,
    SubmissionText NVARCHAR(MAX),
    AttachmentUrl NVARCHAR(MAX),
    MarksObtained DECIMAL(5,2),
    Remarks NVARCHAR(MAX),
    GradedBy INT NULL,
    GradedAt DATETIME2 NULL,
    IsSubmitted BIT DEFAULT 0,
    CONSTRAINT FK_SAS_Assignment FOREIGN KEY (AssignmentId) 
        REFERENCES Assignments(AssignmentId),
    CONSTRAINT FK_SAS_Student FOREIGN KEY (StudentEnrollmentId) 
        REFERENCES StudentEnrollments(EnrollmentId),
    CONSTRAINT FK_SAS_GradedBy FOREIGN KEY (GradedBy) REFERENCES Users(UserId)
);

-- =============================================================================
-- MODULE 7: FINANCE (Accrual Based System)
-- =============================================================================

-- 36. Fee Heads (Types of Fees)
CREATE TABLE FeeHeads (
    FeeHeadId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    Name NVARCHAR(100) NOT NULL, -- Tuition, Bus, Uniform
    Type TINYINT DEFAULT 1, -- 1=Standard, 2=Optional
    IsActive BIT DEFAULT 1,
    CONSTRAINT FK_FH_School FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId)
);

-- 37. Fee Structures (Pricing)
CREATE TABLE FeeStructures (
    FeeStructureId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    AcademicYearId INT NOT NULL,
    ClassId INT NOT NULL,
    FeeHeadId INT NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    Frequency TINYINT DEFAULT 1, -- 1=Monthly, 2=Quarterly, 3=Annually
    CONSTRAINT FK_FS_School FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_FS_Year FOREIGN KEY (AcademicYearId) REFERENCES AcademicYears(YearId),
    CONSTRAINT FK_FS_Class FOREIGN KEY (ClassId) REFERENCES Classes(ClassId),
    CONSTRAINT FK_FS_Head FOREIGN KEY (FeeHeadId) REFERENCES FeeHeads(FeeHeadId)
);

-- 38. Student Fee Dues (Invoices)
CREATE TABLE StudentFeeDues (
    DueId BIGINT IDENTITY(1,1) PRIMARY KEY,
    StudentEnrollmentId INT NOT NULL,
    FeeHeadId INT NOT NULL,
    Title NVARCHAR(200),
    Amount DECIMAL(18,2) NOT NULL,
    DueDate DATE NOT NULL,
    IsPaid BIT DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    DeletedAt DATETIME2 NULL,
    CONSTRAINT FK_Dues_Enrollment FOREIGN KEY (StudentEnrollmentId) 
        REFERENCES StudentEnrollments(EnrollmentId),
    CONSTRAINT FK_Dues_FeeHead FOREIGN KEY (FeeHeadId) REFERENCES FeeHeads(FeeHeadId)
);

-- 39. Payments (Transactions)
CREATE TABLE Payments (
    PaymentId BIGINT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    StudentId INT NOT NULL, -- Use StudentId here for long-term history
    Amount DECIMAL(18,2),
    Mode NVARCHAR(50),
    ReferenceNo NVARCHAR(100),
    TransactionId NVARCHAR(100), -- Payment gateway tracking
    Status TINYINT DEFAULT 1, -- 1=Success, 2=Pending, 3=Failed, 4=Refunded
    PaidAt DATETIME2 DEFAULT SYSDATETIME(),
    ReversedAt DATETIME2 NULL,
    ReversedBy INT NULL,
    CONSTRAINT FK_Payments_School FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_Payments_Students FOREIGN KEY (StudentId) REFERENCES Students(StudentId),
    CONSTRAINT FK_Payments_ReversedBy FOREIGN KEY (ReversedBy) REFERENCES Users(UserId)
);

-- 40. Payment Allocations (Mapping Payment -> Dues)
CREATE TABLE PaymentAllocations (
    AllocationId BIGINT IDENTITY(1,1) PRIMARY KEY,
    PaymentId BIGINT NOT NULL,
    DueId BIGINT NOT NULL,
    AmountAllocated DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_Alloc_Payment FOREIGN KEY (PaymentId) REFERENCES Payments(PaymentId),
    CONSTRAINT FK_Alloc_Due FOREIGN KEY (DueId) REFERENCES StudentFeeDues(DueId)
);

-- 41. Payment Adjustments (NEW)
CREATE TABLE PaymentAdjustments (
    AdjustmentId BIGINT IDENTITY(1,1) PRIMARY KEY,
    PaymentId BIGINT,
    DueId BIGINT,
    AdjustmentAmount DECIMAL(18,2) NOT NULL,
    AdjustmentType NVARCHAR(50) NOT NULL, -- 'Refund', 'AdjustmentUp', 'AdjustmentDown'
    Reason NVARCHAR(500),
    CreatedBy INT NOT NULL,
    CreatedAt DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Adj_Payment FOREIGN KEY (PaymentId) 
        REFERENCES Payments(PaymentId),
    CONSTRAINT FK_Adj_Due FOREIGN KEY (DueId) 
        REFERENCES StudentFeeDues(DueId),
    CONSTRAINT FK_Adj_CreatedBy FOREIGN KEY (CreatedBy) 
        REFERENCES Users(UserId)
);

-- =============================================================================
-- MODULE 8: COMMUNICATION
-- =============================================================================

-- 42. Notices
CREATE TABLE Notices (
    NoticeId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    BranchId INT NULL, -- Null = All Branches
    Title NVARCHAR(200),
    Message NVARCHAR(MAX),
    Audience NVARCHAR(50), -- 'Students', 'Teachers', 'All'
    PublishedAt DATETIME2 DEFAULT SYSDATETIME(),
    IsActive BIT DEFAULT 1,
    CONSTRAINT FK_Notices_Schools FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_Notices_Branches FOREIGN KEY (BranchId) REFERENCES Branches(BranchId)
);

-- =============================================================================
-- MODULE 9: TRANSPORT
-- =============================================================================

-- 43. Transport Routes
CREATE TABLE TransportRoutes (
    RouteId INT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    Name NVARCHAR(100),
    VehicleNo NVARCHAR(50),
    DriverName NVARCHAR(100),
    DriverPhone NVARCHAR(20),
    IsActive BIT DEFAULT 1,
    CONSTRAINT FK_TR_School FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId)
);

-- 44. Student Transport
CREATE TABLE StudentTransport (
    TransportId INT IDENTITY(1,1) PRIMARY KEY,
    StudentEnrollmentId INT NOT NULL,
    RouteId INT NOT NULL,
    PickupPoint NVARCHAR(100),
    DropPoint NVARCHAR(100),
    IsActive BIT DEFAULT 1,
    CONSTRAINT FK_ST_Route FOREIGN KEY (RouteId) REFERENCES TransportRoutes(RouteId),
    CONSTRAINT FK_ST_Student FOREIGN KEY (StudentEnrollmentId) 
        REFERENCES StudentEnrollments(EnrollmentId)
);

-- =============================================================================
-- MODULE 10: AUDIT & LOGGING
-- =============================================================================

-- 45. Audit Logs (Enhanced)
CREATE TABLE AuditLogs (
    LogId BIGINT IDENTITY(1,1) PRIMARY KEY,
    SchoolId INT NOT NULL,
    UserId INT NOT NULL,
    Action NVARCHAR(50) NOT NULL,
    TableName NVARCHAR(50) NOT NULL,
    RecordId NVARCHAR(50),
    OldValue NVARCHAR(MAX),
    NewValue NVARCHAR(MAX),
    Details NVARCHAR(MAX), -- JSON
    IPAddress NVARCHAR(45),
    UserAgent NVARCHAR(500),
    Timestamp DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_AL_School FOREIGN KEY (SchoolId) REFERENCES Schools(SchoolId),
    CONSTRAINT FK_AL_User FOREIGN KEY (UserId) REFERENCES Users(UserId)
);

-- =============================================================================
-- INDEXES (Performance Optimization)
-- =============================================================================

-- Core Tenancy Indexes
CREATE INDEX IX_Users_School ON Users(SchoolId) WHERE DeletedAt IS NULL;
CREATE UNIQUE INDEX IX_Users_Login ON Users (Username) 
    INCLUDE (PasswordHash, UserId, SchoolId, RoleId) WHERE DeletedAt IS NULL;

-- Multi-Role Support
CREATE INDEX IX_UserRoles_User ON UserRoles(UserId, DeletedAt);
CREATE INDEX IX_UserRoles_Role ON UserRoles(RoleId, DeletedAt);

-- Academic & Enrollment Indexes
CREATE UNIQUE INDEX IX_StudentEnrollment_Active 
    ON StudentEnrollments(StudentId, AcademicYearId) 
    WHERE Status = 1 AND DeletedAt IS NULL;

CREATE INDEX IX_StudentEnrollment_Student ON StudentEnrollments(StudentId, AcademicYearId)
    INCLUDE (ClassId, SectionId, Status);

CREATE INDEX IX_Progression_Enrollment ON StudentProgressions(StudentEnrollmentId);
CREATE INDEX IX_Progression_FromYear ON StudentProgressions(FromAcademicYearId);

-- Attendance Indexes
CREATE INDEX IX_Attendance_YearDate ON Attendance(AcademicYearId, Date)
    INCLUDE (Status, StudentEnrollmentId) WHERE DeletedAt IS NULL;

CREATE INDEX IX_Attendance_EnrollmentDate ON Attendance(StudentEnrollmentId, Date DESC)
    INCLUDE (Status) WHERE DeletedAt IS NULL;

-- Leave Management Indexes
CREATE INDEX IX_StudentLeaves_Enrollment ON StudentLeaves(StudentEnrollmentId, Status);
CREATE INDEX IX_TeacherLeaves_Teacher ON TeacherLeaves(TeacherId, Status);

-- Exam & Results Indexes
CREATE INDEX IX_ExamSchedules_ExamSubject ON ExamSchedules(ExamSubjectId, ExamDate);
CREATE UNIQUE INDEX IX_HallTicket_Unique ON HallTickets(ExamScheduleId, StudentEnrollmentId);
CREATE INDEX IX_HallTicket_Seat ON HallTickets(ExamScheduleId, SeatNumber);
CREATE INDEX IX_Results_Student ON Results(StudentEnrollmentId);
CREATE INDEX IX_Results_ExamSubject ON Results(ExamSubjectId);

-- Assignment Indexes
CREATE INDEX IX_Assignments_ClassSubject ON Assignments(ClassSubjectId, DeletedAt);
CREATE INDEX IX_Submissions_Assignment ON StudentAssignmentSubmissions(AssignmentId);
CREATE INDEX IX_Submissions_Student ON StudentAssignmentSubmissions(StudentEnrollmentId);

-- Conduct Records Index
CREATE INDEX IX_ConductRecords_Enrollment ON StudentConductRecords(StudentEnrollmentId, DeletedAt);
CREATE INDEX IX_ConductRecords_Type ON StudentConductRecords(RecordType, DeletedAt);

-- Financial Indexes
CREATE INDEX IX_StudentFeeDues_Enrollment ON StudentFeeDues(StudentEnrollmentId, IsPaid)
    INCLUDE (Amount, DueDate) WHERE DeletedAt IS NULL;

CREATE INDEX IX_Payments_Student ON Payments(StudentId, Status);
CREATE INDEX IX_PaymentAdjustment_Payment ON PaymentAdjustments(PaymentId);
CREATE INDEX IX_PaymentAdjustment_Due ON PaymentAdjustments(DueId);

-- Communication Indexes
CREATE INDEX IX_Notices_School ON Notices(SchoolId, PublishedAt);

-- Academic Structure Indexes
CREATE INDEX IX_Classes_School ON Classes(SchoolId, BranchId) WHERE DeletedAt IS NULL;
CREATE INDEX IX_Sections_Class ON Sections(ClassId) WHERE DeletedAt IS NULL;
CREATE INDEX IX_Subjects_School ON Subjects(SchoolId) WHERE DeletedAt IS NULL;
CREATE INDEX IX_ClassSubjects_Year ON ClassSubjects(AcademicYearId, ClassId) 
    WHERE DeletedAt IS NULL;

-- Timetable Indexes
CREATE INDEX IX_Timetable_ClassSection ON Timetable(ClassId, SectionId, DayOfWeek);

-- Audit Indexes
CREATE INDEX IX_AuditLogs_School ON AuditLogs(SchoolId, Timestamp DESC);
CREATE INDEX IX_AuditLogs_User ON AuditLogs(UserId, Timestamp DESC);
CREATE INDEX IX_AuditLogs_Action ON AuditLogs(Action, Timestamp DESC);

-- Parent-Student Indexes
CREATE INDEX IX_ParentStudents_Parent ON ParentStudents(ParentId);
CREATE INDEX IX_ParentStudents_Student ON ParentStudents(StudentId);

-- Session Management
CREATE INDEX IX_UserSessions_User ON UserSessions(UserId, ExpiresAt);

-- =============================================================================
-- COMPLETION SUMMARY
-- =============================================================================
-- Total Tables: 45
-- Original Tables (V2): 32
-- New Enhancement Tables: 13
--   - UserRoles (Multi-role support)
--   - UserSessions (Security)
--   - SchoolConfigurations (Flexibility)
--   - StudentProgressions (Promotions)
--   - LeaveTypes, StudentLeaves, TeacherLeaves (Leave management)
--   - StudentConductRecords (Behavior tracking)
--   - ExamSchedules, HallTickets (Exam operations)
--   - Assignments, StudentAssignmentSubmissions (Homework)
--   - PaymentAdjustments (Financial corrections)
--
-- Enhanced Tables:
--   - StudentEnrollments (Added CreatedAt, TransferredAt, DeletedAt)
--   - Attendance (Added AcademicYearId, DeletedAt)
--   - Payments (Added Status, TransactionId, ReversedAt, ReversedBy)
--   - Multiple tables with DeletedAt for soft delete pattern
--
-- Total Indexes: 50+
-- =============================================================================
