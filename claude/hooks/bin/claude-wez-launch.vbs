' Windowless launcher for the Claude toast-click handler. pwsh is a console app, so
' protocol-launching it directly flashes the Win11 default terminal (Windows Terminal)
' even with -WindowStyle Hidden. wscript has no console and Run(cmd, 0, False) starts
' pwsh fully hidden -> no flash (confirmed by spike). PURE launcher: the focus-marker
' logic lives in claude-notify.ps1 (-Activate mode, unit-tested). The ps1 is located as a
' sibling so it rides the claude/ -> ~/.claude symlink. Swap this shim if VBScript is ever
' removed from Windows (the logic stays in the ps1). CC_WEZ_DRYRUN: print the command
' instead of launching (test seam).
Dim sh, fso, ps1, uri, cmd
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
ps1 = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "claude-notify.ps1")
uri = ""
If WScript.Arguments.Count > 0 Then uri = WScript.Arguments(0)
If uri = "" Then WScript.Quit 0
cmd = "pwsh -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & ps1 & """ -Activate """ & uri & """"
If sh.ExpandEnvironmentStrings("%CC_WEZ_DRYRUN%") <> "%CC_WEZ_DRYRUN%" Then
  WScript.Echo cmd
Else
  sh.Run cmd, 0, False
End If
