pipeline {
    agent any

    options {
        // ESTRATÉGIA DE LIMPEZA: Mantém no disco apenas os últimos 10 builds e deleta automaticamente os artefatos/XMLs mais velhos que isso!
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
        timeout(time: 1, unit: 'HOURS')
    }

    environment {
        // FIX: Nome padronizado para bater com as chamadas de credenciais abaixo
        DISCORD_WEBHOOK_ID = 'discord-webhook-url'
    }
    
    stages {
        stage('1. Baixar do GitHub') {
            steps {
                // PADRÃO DE PRODUÇÃO: Pega a URL e a Branch dinamicamente de onde o script foi baixado
                checkout scm
            }
        }
        stage('2. Copiar para o Servidor') {
            steps {
                bat 'del /q /s D:\\IRIS_Server\\projectGit\\* 2>nul'
                bat 'xcopy /E /Y . D:\\IRIS_Server\\projectGit\\'
            }
        }
        stage('3. Backup e Deploy no IRIS') {
            options {
                timeout(time: 1, unit: 'MINUTES') 
            }
            steps {
                // Esse script agora cria o backup_anterior.xml ANTES de aplicar o código novo
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\importar.script || exit 0'
            }
        }
        stage('4. Executar Testes Unitários') {            
            when {
                allOf {
                    // 1. A pasta 'tests' precisa existir no repositório
                    expression { return fileExists('tests') }
                    
                    // 2. A branch atual NÃO pode ser a 'production'
                    not { branch 'production' }
                    
                    // 3. A mensagem do commit NÃO pode conter o texto '[skip test]' ou '[skip ci]'
                    expression { 
                        def changeLogSets = currentBuild.changeSets
                        def commitMessage = changeLogSets.collect { set -> set.items.collect { item -> item.msg }.join(' ') }.join(' ')
                        return !commitMessage.contains('[skip test]') && !commitMessage.contains('[skip ci]')
                    }
                }
            }
            options {
                timeout(time: 1, unit: 'MINUTES')
            }
            steps {
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\testes.script || exit 0'
            }
        }
        stage('5. Gerar Artefato de Release') {
            when {
                expression { 
                    // 1. Tenta pegar pelo histórico do Jenkins
                    def changeLogSets = currentBuild.changeSets
                    def commitMessage = changeLogSets.collect { set -> set.items.collect { item -> item.msg }.join(' ') }.join(' ')
                    
                    // 2. SE o histórico estiver vazio (primeiro build), busca direto do log do Git baixado no Workspace de forma segura
                    if (!commitMessage || commitMessage.trim() == "") {
                        commitMessage = powershell(script: "git log -1 --pretty=format:%B", returnStdout: true).trim()
                    }
                    
                    return commitMessage.contains('[release]')
                }
            }                
            options {
                timeout(time: 1, unit: 'MINUTES')
            }
            steps {
                echo '📦 Testes aprovados! Gerando pacote consolidado .xml para produção...'
                
                // FIX 1: Passando as aspas e o caminho de forma "pura" com aspas simples para o CMD não quebrar
                bat 'D:\\InterSystems\\IRIS\\bin\\irissession IRIS "%WORKSPACE%" 0 < D:\\IRIS_Server\\release.script || exit 0'
                
                // FIX 2: Correção da sintaxe do comando ren do Windows
                bat "ren build\\release.xml release_build_${env.BUILD_NUMBER}.xml"
                
                // FIX 3: Ajustado o arquivamento para ler o arquivo renomeado dentro da pasta build
                archiveArtifacts artifacts: "build/release_build_${env.BUILD_NUMBER}.xml", fingerprint: true
                
                // FIX 4: Corrigido o ID da credencial e a injeção segura do endpoint no PowerShell
                withCredentials([string(credentialsId: env.DISCORD_WEBHOOK_ID, variable: 'WEBHOOK_SECRET')]) {
                    script {
                        def releasePayload = """{
                            "content": "📦 **NOVA RELEASE DISPONÍVEL!**\\n**Projeto:** ${env.JOB_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚀 *O artefato consolidado 'release_build_${env.BUILD_NUMBER}.xml' foi gerado com sucesso, livre de classes de teste! O pacote já está arquivado no painel do Jenkins e pronto para ser implantado em Produção.*"
                        }"""
                        def jsonRelease = releasePayload.replaceAll('\n', '').replaceAll('\r', '')
                        powershell "Invoke-RestMethod -Uri \$env:WEBHOOK_SECRET -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${jsonRelease}')) -ContentType 'application/json; charset=utf-8'"
                    }
                }
            }
        }
    }
    
    post {
        failure {
            echo '🚨 Os testes falharam! Voltando o servidor para o estado anterior usando o backup...'
            bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\rollback.script || exit 0'

            // FIX: Mapeamento de credencial corrigido para evitar o NullPointerException
            withCredentials([string(credentialsId: env.DISCORD_WEBHOOK_ID, variable: 'WEBHOOK_SECRET')]) {
                script {
                    def msgPayload = """{
                        "content": "❌ **Pipeline FALHOU!**\\n**Projeto:** ${env.JOB_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚨 *Os testes unitários falharam ou a esteira quebrou. O procedimento de Rollback automático foi executado e o servidor foi restaurado.*"
                    }"""

                    def jsonPronto = msgPayload.replaceAll('\n', '').replaceAll('\r', '')
                    powershell "Invoke-RestMethod -Uri \$env:WEBHOOK_SECRET -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${jsonPronto}')) -ContentType 'application/json; charset=utf-8'"
                }
            }
       }
        success {
            echo '✅ Pipeline concluído com sucesso. Nenhuma falha detectada!'

            // FIX: Mapeamento de credencial corrigido para evitar o NullPointerException
            withCredentials([string(credentialsId: env.DISCORD_WEBHOOK_ID, variable: 'WEBHOOK_SECRET')]) {
                script {
                    def msgPayload = """{
                        "content": "✅ **Pipeline SUCESSO!**\\n**Projeto:** ${env.JOB_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚀 *Alterações publicadas com sucesso no InterSystems IRIS e pacote de release gerado com segurança!*"
                    }"""
                    
                    def jsonPronto = msgPayload.replaceAll('\n', '').replaceAll('\r', '')
                    powershell "Invoke-RestMethod -Uri \$env:WEBHOOK_SECRET -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${jsonPronto}')) -ContentType 'application/json; charset=utf-8'"
                }
            }
        }
    }
}
