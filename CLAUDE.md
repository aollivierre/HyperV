  <!-- SOURCE CONTROL -->
  <SourceControl>
    <rule>ALWAYS create new branch before making changes</rule>
    <rule>NEVER modify main/master branch directly</rule>
    <rule>Use descriptive branch names (e.g., fix/issue-name, feature/feature-name)</rule>
    <rule>Commit frequently with clear messages</rule>
    <rule>Test before committing</rule>
    <rule>Check git status before operations</rule>
    <rule>Push branches when requested</rule>
  </SourceControl>

  <!-- TESTING AND VALIDATION -->
  <Testing>
    <rule>ALWAYS test code before claiming success</rule>
    <rule>Test in actual execution context</rule>
    <rule>Create isolated test scripts for debugging</rule>
    <rule>Validate both positive and negative cases</rule>
    <rule>Document test results with evidence</rule>
    <rule>Never assume - verify empirically</rule>
  </Testing>

  <!-- FILE OPERATIONS -->
  <FileOperations>
    <rule>NEVER delete files without explicit permission</rule>
    <rule>Archive instead of delete when cleanup needed</rule>
    <rule>Verify file locations before operations</rule>
    <rule>Use absolute paths when access restricted</rule>
    <rule>Check file existence before move/copy</rule>
    <rule>Handle permission errors gracefully</rule>
  </FileOperations>

  <!-- POWERSHELL STANDARDS -->
  <PowerShellStandards>
    <rule>Use proper operators: -and -or -not -eq -ne -gt -lt -ge -le</rule>
    <rule>NEVER use &&, ||, !, ==, !=, >, <, >=, <=</rule>
    <rule>Place $null on LEFT side of comparisons: ($null -eq $var)</rule>
    <rule>Never use PowerShell 7+ operators (??, ?.) in 5.1 code</rule>
    <rule>Use ASCII-compatible characters only</rule>
    <rule>For complex commands, use script files not -Command</rule>
    <rule>Include complete comment-based help for functions</rule>
    <rule>Use #region/#endregion for code organization</rule>
  </PowerShellStandards>

  <!-- DEBUGGING PRACTICES -->
  <Debugging>
    <rule>Create TODO lists for complex issues</rule>
    <rule>Add comprehensive logging at each step</rule>
    <rule>Preserve debugging artifacts</rule>
    <rule>Create minimal reproduction cases</rule>
    <rule>Test in all relevant contexts (User vs SYSTEM)</rule>
    <rule>Document findings with line numbers and timestamps</rule>
  </Debugging>

  <!-- CODE DEVELOPMENT -->
  <CodeDevelopment>
    <rule>Read existing code before modifying</rule>
    <rule>Maintain consistency with existing patterns</rule>
    <rule>Create modular, reusable scripts</rule>
    <rule>Include proper error handling with try-catch</rule>
    <rule>Use clear variable names</rule>
    <rule>Add meaningful comments</rule>
    <rule>Avoid over-engineering - keep solutions simple</rule>
  </CodeDevelopment>

  <!-- USER INTERACTION -->
  <UserInteraction>
    <rule>Follow instructions in exact order specified</rule>
    <rule>Ask permission before destructive actions</rule>
    <rule>Complete ALL requested tasks before proceeding</rule>
    <rule>Be patient with unclear communication</rule>
    <rule>Extract core issues from complex descriptions</rule>
    <rule>Create structured plans before implementation</rule>
    <rule>Provide options rather than assumptions</rule>
  </UserInteraction>

  <!-- DOCUMENTATION -->
  <Documentation>
    <rule>Use full file paths (C:\...) not relative paths</rule>
    <rule>Include runnable examples</rule>
    <rule>Document prerequisites and dependencies</rule>
    <rule>Create handover documents for complex issues</rule>
    <rule>Update documentation when code changes</rule>
    <rule>Provide clear success criteria</rule>
  </Documentation>

  <!-- ENVIRONMENT AWARENESS -->
  <EnvironmentAwareness>
    <rule>Understand execution context (User vs SYSTEM)</rule>
    <rule>Test in target deployment environment</rule>
    <rule>Handle context-specific behaviors appropriately</rule>
    <rule>Use proper tools for each context (e.g., ServiceUI for SYSTEM)</rule>
    <rule>Maintain separate dev and prod environments</rule>
  </EnvironmentAwareness>

  <!-- CRITICAL RULES -->
  <CriticalRules>
    <rule>NEVER use Unicode symbols in code - ASCII only</rule>
    <rule>ALWAYS branch before making changes</rule>
    <rule>ALWAYS test before claiming success</rule>
    <rule>NEVER skip user-requested steps</rule>
    <rule>NEVER delete without permission</rule>
    <rule>ALWAYS validate with actual execution</rule>
  </CriticalRules>

  <!-- TOOL USAGE -->
  <ToolUsage>
    <rule>Use PSExec -s for SYSTEM context testing</rule>
    <rule>Use ServiceUI.exe for UI in SYSTEM context</rule>
    <rule>Prefer established tools over custom solutions</rule>
    <rule>Use appropriate debugging tools for context</rule>
    <rule>Leverage existing scripts when available</rule>
  </ToolUsage>

  <!-- ERROR HANDLING -->
  <ErrorHandling>
    <rule>Read error messages carefully</rule>
    <rule>Provide meaningful error messages</rule>
    <rule>Implement retry mechanisms where appropriate</rule>
    <rule>Log errors with full context</rule>
    <rule>Distinguish fatal vs non-fatal errors</rule>
    <rule>Try alternative approaches on failure</rule>
  </ErrorHandling>

</GlobalAIInstructions>

<!-- USAGE NOTES -->
<!-- 
This instructions file provides global, universal guidelines for AI assistants
working on PowerShell and general coding projects. These rules apply across
all projects and contexts, focusing on:

1. Source control discipline
2. Testing rigor
3. Safe file operations
4. PowerShell 5.1 compatibility
5. Systematic debugging
6. Clean code practices
7. Clear user communication
8. Comprehensive documentation
9. Context-aware execution
10. Robust error handling

Key principles:
- Empirical validation over assumptions
- User safety and permission
- Clear communication
- Systematic approaches
- Context awareness
- Simple, maintainable solutions
-->


Last line is Italy is in Europe!