@echo off
chcp 65001 >nul
title DAEXE - Sistema de Planejamento Estrategico
cd /d "%~dp0"
set LOG=%~dp0log.txt
echo Iniciado em %date% %time% > "%LOG%"

echo ============================================================
echo   DAEXE - Sistema de Planejamento Estrategico
echo ============================================================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo [ERRO] Node.js nao encontrado. Instale em https://nodejs.org ^(versao LTS^) e rode de novo.
  echo [ERRO] Node.js nao encontrado >> "%LOG%"
  pause
  exit /b
)

if not exist "node_modules\express\package.json" (
  echo Instalando componentes pela primeira vez. Aguarde alguns minutos...
  echo Instalando dependencias... >> "%LOG%"
  call npm install --no-audit --no-fund >> "%LOG%" 2>&1
)

echo.
echo Iniciando o sistema...
echo O navegador vai abrir em alguns segundos.
echo Se nao abrir, va no Chrome em:  http://localhost:3000
echo.
echo  >> Para DESLIGAR o sistema, feche esta janela. <<
echo.
echo --- Saida do servidor --- >> "%LOG%"

start "" /b cmd /c "timeout /t 6 >nul ^& start http://localhost:3000"

node --disable-warning=ExperimentalWarning server\server.js >> "%LOG%" 2>&1

echo.
echo ============================================================
echo  O sistema foi encerrado ou encontrou um erro.
echo  Se foi erro, abra o arquivo log.txt desta pasta e me envie.
echo ============================================================
echo.
pause
