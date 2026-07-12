# Sistema de Planejamento Estratégico DAEXE

Aplicação web multiusuário que substitui a planilha de Planejamento Estratégico 2026 da Daexe. Reúne todos os módulos da planilha em uma interface simples e intuitiva, com controle de acesso por papel.

## Módulos

- **Painel** — visão geral com indicadores, gráficos de desempenho e prioridades GUT
- **Filosofia** — Missão, Visão, Valores e dados da empresa
- **Departamentos** — áreas e níveis de atuação
- **SWOT / GUT** — diagnóstico com priorização Gravidade × Urgência × Tendência
- **Curva de Valor** — comparação DAEXE × concorrência
- **Mapa BSC** — mapa estratégico nas 4 perspectivas (Financeira, Clientes, Processos, Inovação e Pessoas)
- **Objetivos & Metas (OKR/BSC)** — objetivos estratégicos e metas SMART
- **Iniciativas (5W2H)** — plano de ação completo (Quê, Quem, Quando, Como, Quanto, Onde, Porquê)
- **Desempenho de Metas** — acompanhamento semanal/mensal/trimestral
- **Avaliação** — avaliação de desempenho (auto + gestor) por competência
- **Usuários & Acessos** — gestão de usuários, papéis e lembretes

## Papéis de acesso

| Papel | Permissões |
|---|---|
| **Administrador** | Tudo: usuários, acessos, estrutura e configurações |
| **Gestor** | Objetivos, metas, departamentos, valores; envia lembretes |
| **Colaborador** | Insere/atualiza SWOT, iniciativas, desempenho e auto avaliação |
| **Visualizador** | Apenas consulta painéis e relatórios |

## Como rodar

Pré-requisito: [Node.js](https://nodejs.org) 18 ou superior.

```bash
cd daexe-scp
# se existir uma pasta node_modules parcial, apague-a antes:
#   (Windows)  rmdir /s /q node_modules  &  del package-lock.json
npm install
npm start
```

Acesse **http://localhost:3000**

### Usuários de demonstração (senha: `daexe123`)
- `admin@daexe.com.br` — Administrador
- `gestor@daexe.com.br` — Gestor
- `colaborador@daexe.com.br` — Colaborador
- `visual@daexe.com.br` — Visualizador

> O banco (SQLite) é criado e populado automaticamente em `data/daexe.db` na primeira execução, com os dados reais da planilha 2026.

## Exportações e integrações

- **Excel / PDF** — botões no topo de qualquer tela geram o plano completo para download.
- **E-mail / notificações** — lembretes registrados no sistema. Para envio real de e-mail, defina as variáveis `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` e instale `nodemailer` (instruções em `server/notify.js`).
- **Google Drive / Sheets** — os arquivos Excel exportados podem ser enviados ao Drive; ponto de integração preparado para conector futuro.

## Stack

Node.js + Express · SQLite (better-sqlite3) · JWT + bcrypt · SPA em HTML/CSS/JS puro · Chart.js · ExcelJS · PDFKit.

## Segurança

Antes de usar em produção: troque `JWT_SECRET` (variável de ambiente) e as senhas padrão dos usuários de demonstração.
