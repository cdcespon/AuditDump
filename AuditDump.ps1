# ============================================================
# AuditDump.ps1
# Genera archivos de auditoria organizados por capa en
# formato Markdown - generico para cualquier proyecto
# Hualco / Antigravity bajo Clean Architecture
#
# Location: C:\Development\Antigravity\_Tools\AuditDump.ps1
#
# Usage:
#   C:\Development\Antigravity\_Tools\AuditDump.ps1 -ProjectRoot "C:\Development\Antigravity\Hualco.Comex"
#   C:\Development\Antigravity\_Tools\AuditDump.ps1 -ProjectRoot "C:\Development\Antigravity\Hualco.Panoptico"
#   C:\Development\Antigravity\_Tools\AuditDump.ps1 -ProjectRoot "C:\Development\Antigravity\Hualco.Cargo" -OutputDir "D:\Audits\Cargo"
#
# Output por defecto: <ParentOfProjectRoot>\_AuditDump\<ProjectName>\
#
# NOTA - Execution Policy:
#   Si PowerShell bloquea la ejecucion del script, usa:
#   PowerShell -ExecutionPolicy Bypass -File "C:\Development\Antigravity\_Tools\AuditDump.ps1" -ProjectRoot "C:\Development\Antigravity\Hualco.Comex"
#
#   O para habilitarlo de forma permanente para el usuario actual (requiere que
#   no haya una Group Policy que lo bloquee):
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# ============================================================

param(
    [string]$ProjectRoot = "",
    [string]$OutputDir   = ""
)

# -- Solicitar ProjectRoot si no fue provisto -----------------
if ($ProjectRoot -eq "") {
    Write-Host ""
    Write-Host "  ProjectRoot no especificado."
    Write-Host "  Ejemplo: C:\Development\Antigravity\Hualco.Comex"
    Write-Host ""
    $ProjectRoot = Read-Host "  Ingresa el path del proyecto"
    $ProjectRoot = $ProjectRoot.Trim().Trim('"')
}

# -- Validar que el directorio existe ------------------------
if ($ProjectRoot -eq "" -or -not (Test-Path $ProjectRoot)) {
    Write-Error "ProjectRoot no existe o no fue ingresado: $ProjectRoot"
    exit 1
}

# -- Derivar nombre del proyecto desde el directorio ---------
$ProjectName = Split-Path $ProjectRoot -Leaf

# -- Output dir: por defecto junto al proyecto ---------------
if ($OutputDir -eq "") {
    $OutputDir = Join-Path (Split-Path $ProjectRoot -Parent) "_AuditDump\$ProjectName"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
Write-Host ""
Write-Host "========================================"
Write-Host " Audit Dump: $ProjectName"
Write-Host " Output:     $OutputDir"
Write-Host " Generated:  $timestamp"
Write-Host "========================================"
Write-Host ""

# -- Filtro global --------------------------------------------
function ShouldInclude($fullPath) {
    $fullPath -notmatch "\\obj\\"         -and
    $fullPath -notmatch "\\bin\\"         -and
    $fullPath -notmatch "\\Migrations\\"  -and
    $fullPath -notmatch "\\.git\\"        -and
    $fullPath -notmatch "\\node_modules\\"
}

# -- Helper: bloque markdown por archivo ---------------------
function Write-FileBlock($writer, $file, $root) {
    $rel = $file.FullName.Replace($root, "").TrimStart("\")
    $ext = $file.Extension.TrimStart(".").ToLower()

    $lang = switch ($ext) {
        "cs"      { "csharp" }
        "csproj"  { "xml" }
        "props"   { "xml" }
        "targets" { "xml" }
        "xml"     { "xml" }
        "json"    { "json" }
        "yaml"    { "yaml" }
        "yml"     { "yaml" }
        "sql"     { "sql" }
        "md"      { "markdown" }
        "js"      { "javascript" }
        "ts"      { "typescript" }
        "razor"   { "razor" }
        "html"    { "html" }
        "css"     { "css" }
        "scss"    { "scss" }
        default   { "" }
    }

    $writer.WriteLine("")
    $writer.WriteLine("---")
    $writer.WriteLine("")
    $writer.WriteLine("### ``$rel``")
    $writer.WriteLine("")
    $writer.WriteLine("``````$lang")
    try {
        $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
        $writer.WriteLine($content.TrimEnd())
    } catch {
        $writer.WriteLine("// [ERROR READING FILE: $_]")
    }
    $writer.WriteLine("``````")
}

# -- Funcion: recolectar archivos por patrones ---------------
function Get-LayerFiles($root, [string[]]$pathPatterns, [string[]]$namePatterns) {
    Get-ChildItem -Path $root -Recurse -Include "*.cs","*.csproj","*.json","*.yaml","*.yml","*.sql","*.js","*.ts","*.razor","*.html","*.css","*.scss" |
        Where-Object {
            if (-not (ShouldInclude $_.FullName)) { return $false }
            $rel  = $_.FullName.Replace($root, "").ToLower()
            $name = $_.Name.ToLower()
            foreach ($p in $pathPatterns) {
                if ($rel -match $p.ToLower()) { return $true }
            }
            foreach ($n in $namePatterns) {
                if ($name -match $n.ToLower()) { return $true }
            }
            return $false
        } |
        Sort-Object FullName
}

# -- Helper: escribir archivo MD por capa -------------------
function Write-LayerFile($fileName, $title, $files) {
    $path = "$OutputDir\$fileName"
    $sw   = [System.IO.StreamWriter]::new($path, $false, [System.Text.Encoding]::UTF8)

    $sw.WriteLine("# $ProjectName - $title")
    $sw.WriteLine("")
    $sw.WriteLine("> Generated: $timestamp")
    $sw.WriteLine("> Root: ``$ProjectRoot``")
    $sw.WriteLine("> Files in this dump: **$($files.Count)**")
    $sw.WriteLine("")

    if ($files.Count -eq 0) {
        $sw.WriteLine("_No files matched for this layer._")
    } else {
        foreach ($f in $files) {
            Write-FileBlock $sw $f $ProjectRoot
        }
    }

    $sw.Close()
    Write-Host "  [$fileName] -> $($files.Count) archivos"
}

# ============================================================
# 00 - TREE
# ============================================================
Write-Host "Generando 00_tree.md..."
$allFiles = Get-ChildItem -Path $ProjectRoot -Recurse -File |
    Where-Object { ShouldInclude $_.FullName } |
    Select-Object -ExpandProperty FullName |
    ForEach-Object { $_.Replace($ProjectRoot, "").TrimStart("\") } |
    Sort-Object

$treePath = "$OutputDir\00_tree.md"
$tw = [System.IO.StreamWriter]::new($treePath, $false, [System.Text.Encoding]::UTF8)

$tw.WriteLine("# $ProjectName - File Tree")
$tw.WriteLine("")
$tw.WriteLine("> Generated: $timestamp")
$tw.WriteLine("> Root: ``$ProjectRoot``")
$tw.WriteLine("> Total files (excl. obj/bin/migrations): **$($allFiles.Count)**")
$tw.WriteLine("")

# -- Context -------------------------------------------------
$tw.WriteLine("## Context")
$tw.WriteLine("")
$tw.WriteLine("Este dump fue generado por ``AuditDump.ps1`` y contiene el codigo fuente")
$tw.WriteLine("de ``$ProjectName`` organizado por capa arquitectonica.")
$tw.WriteLine("")
$tw.WriteLine("| Archivo                  | Contenido                                             |")
$tw.WriteLine("|--------------------------|-------------------------------------------------------|")
$tw.WriteLine("| ``00_tree.md``           | Este archivo. Estructura completa de archivos         |")
$tw.WriteLine("| ``01_domain.md``         | Entidades, VOs, eventos de dominio, interfaces        |")
$tw.WriteLine("| ``02_application.md``    | Commands, Queries, Handlers, DTOs, Validators         |")
$tw.WriteLine("| ``03_infrastructure.md`` | DbContext, Repos, Config EF, appsettings              |")
$tw.WriteLine("| ``04_api.md``            | Controllers, Endpoints, Middleware, Program.cs        |")
$tw.WriteLine("| ``05_tests.md``          | Tests, Fixtures, Mocks, Builders                      |")
$tw.WriteLine("| ``06_crosscutting.md``   | Extensions, Helpers, Result, Guard, Settings          |")
$tw.WriteLine("")
$tw.WriteLine("> Solicita los archivos que necesites segun el tipo de tarea.")
$tw.WriteLine("")

# -- Audit Prompt --------------------------------------------
$tw.WriteLine("## Audit Prompt")
$tw.WriteLine("")
$tw.WriteLine("Eres un arquitecto .NET senior realizando un analisis de gaps funcionales y tecnicos")
$tw.WriteLine("sobre ``$ProjectName``.")
$tw.WriteLine("")
$tw.WriteLine("Este archivo contiene el tree completo del proyecto. Analiza la estructura,")
$tw.WriteLine("identifica las capas presentes, y solicita los archivos MD que necesitas")
$tw.WriteLine("para producir un informe de gaps con el siguiente formato:")
$tw.WriteLine("")
$tw.WriteLine("### Formato de salida esperado")
$tw.WriteLine("")
$tw.WriteLine("#### GAP-001 - [Titulo]")
$tw.WriteLine("- **Tipo**: Funcional | Tecnico | Arquitectonico | Seguridad | Performance")
$tw.WriteLine("- **Severidad**: Critical | High | Medium | Low")
$tw.WriteLine("- **Capa**: Domain | Application | Infrastructure | API | Crosscutting")
$tw.WriteLine("- **Descripcion**: Que falta o esta mal implementado")
$tw.WriteLine("- **Impacto**: Consecuencia concreta si no se resuelve")
$tw.WriteLine("- **Recomendacion**: Accion correctiva especifica")
$tw.WriteLine("")
$tw.WriteLine("Empieza solicitando los layers en orden de mayor riesgo arquitectonico.")
$tw.WriteLine("")

# -- File Tree -----------------------------------------------
$tw.WriteLine("## File Tree")
$tw.WriteLine("")
$tw.WriteLine('```')
foreach ($f in $allFiles) { $tw.WriteLine($f) }
$tw.WriteLine('```')
$tw.Close()
Write-Host "  [00_tree.md] -> $($allFiles.Count) archivos listados"

# ============================================================
# 01 - DOMAIN
# ============================================================
Write-Host "Generando 01_domain.md..."
$f01 = Get-LayerFiles $ProjectRoot `
    -pathPatterns @("\\domain\\", "\\core\\domain\\", "\.domain\\", "\\domain$") `
    -namePatterns @(
        ".*entity\.cs$", ".*aggregate\.cs$", ".*aggregateroot\.cs$",
        ".*valueobject\.cs$", ".*vo\.cs$",
        ".*domainevent\.cs$", ".*event\.cs$",
        ".*exception\.cs$",
        "^i.*repository\.cs$", "^i.*domain.*\.cs$",
        ".*enum\.cs$", ".*enums\.cs$",
        ".*specification\.cs$"
    )
Write-LayerFile "01_domain.md" "Domain Layer" $f01

# ============================================================
# 02 - APPLICATION
# ============================================================
Write-Host "Generando 02_application.md..."
$f02 = Get-LayerFiles $ProjectRoot `
    -pathPatterns @("\\application\\", "\\app\\", "\.application\\", "\\usecases\\", "\\use.cases\\") `
    -namePatterns @(
        ".*command\.cs$", ".*commandhandler\.cs$",
        ".*query\.cs$", ".*queryhandler\.cs$",
        ".*handler\.cs$",
        ".*dto\.cs$", ".*dtos\.cs$",
        ".*validator\.cs$",
        ".*mapper\.cs$", ".*mappingprofile\.cs$",
        "^i.*service\.cs$", "^i.*usecase\.cs$",
        ".*request\.cs$", ".*response\.cs$",
        ".*pipeline.*\.cs$", ".*behavior.*\.cs$"
    )
Write-LayerFile "02_application.md" "Application Layer" $f02

# ============================================================
# 03 - INFRASTRUCTURE
# ============================================================
Write-Host "Generando 03_infrastructure.md..."
$f03 = Get-LayerFiles $ProjectRoot `
    -pathPatterns @("\\infrastructure\\", "\\infra\\", "\.infrastructure\\", "\\persistence\\", "\\data\\") `
    -namePatterns @(
        ".*dbcontext\.cs$", ".*context\.cs$",
        ".*repository\.cs$",
        ".*configuration\.cs$", ".*entitytypeconfiguration\.cs$",
        ".*seeder\.cs$", ".*seed\.cs$",
        ".*service\.cs$",
        ".*client\.cs$", ".*httpclient\.cs$",
        ".*options\.cs$", "appsettings.*\.json$",
        ".*unitofwork\.cs$"
    )
Write-LayerFile "03_infrastructure.md" "Infrastructure Layer" $f03

# ============================================================
# 04 - API / PRESENTATION
# ============================================================
Write-Host "Generando 04_api.md..."
$f04 = Get-LayerFiles $ProjectRoot `
    -pathPatterns @("\\api\\", "\\web\\", "\\presentation\\", "\\blazor\\", "\\ui\\", "\\host\\", "\\server\\") `
    -namePatterns @(
        ".*controller\.cs$",
        ".*endpoint\.cs$", ".*endpoints\.cs$",
        ".*middleware\.cs$",
        ".*filter\.cs$",
        ".*extension\.cs$",
        "program\.cs$", "startup\.cs$",
        ".*\.razor$", ".*page\.cs$", ".*component\.cs$"
    )
Write-LayerFile "04_api.md" "API / Presentation Layer" $f04

# ============================================================
# 05 - TESTS
# ============================================================
Write-Host "Generando 05_tests.md..."
$f05 = Get-LayerFiles $ProjectRoot `
    -pathPatterns @("\\test\\", "\\tests\\", "\.tests\\", "\.test\\", "\\spec\\") `
    -namePatterns @(
        ".*test\.cs$", ".*tests\.cs$",
        ".*spec\.cs$", ".*fixture\.cs$",
        ".*mock\.cs$", ".*stub\.cs$", ".*fake\.cs$",
        ".*builder\.cs$"
    )
Write-LayerFile "05_tests.md" "Tests" $f05

# ============================================================
# 06 - CROSSCUTTING / SHARED
# ============================================================
Write-Host "Generando 06_crosscutting.md..."
$f06 = Get-LayerFiles $ProjectRoot `
    -pathPatterns @("\\common\\", "\\shared\\", "\\crosscutting\\", "\\extensions\\", "\\helpers\\", "\\utils\\") `
    -namePatterns @(
        ".*extension\.cs$", ".*helper\.cs$",
        ".*constant.*\.cs$", ".*settings\.cs$",
        ".*guard\.cs$", ".*result\.cs$",
        ".*error\.cs$", ".*errors\.cs$"
    )
Write-LayerFile "06_crosscutting.md" "Crosscutting / Shared" $f06

# ============================================================
# RESUMEN FINAL
# ============================================================
Write-Host ""
Write-Host "========================================"
Write-Host " Dump completado."
Write-Host " Archivos generados en:"
Write-Host " $OutputDir"
Write-Host "========================================"
Write-Host ""

Get-ChildItem $OutputDir -Filter "*.md" |
    Select-Object Name, @{N="Size KB";E={[math]::Round($_.Length/1KB,1)}} |
    Format-Table -AutoSize
