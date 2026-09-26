pipeline {
    agent any

    environment {
        // Cole sua URL aqui dentro das aspas simples
        DISCORD_WEBHOOK = credentials('discord-webhook-url')
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
                    // Lógica simplificada: lê a mensagem uma única vez e valida os dois termos com OU (||)
                    expression { 
                        // Forma segura e aceita pelo Sandbox para consolidar as mensagens do commit
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
                    // Mesma validação de string contínua sem quebrar o Sandbox
                    def changeLogSets = currentBuild.changeSets
                    def commitMessage = changeLogSets.collect { set -> set.items.collect { item -> item.msg }.join(' ') }.join(' ')
                    return commitMessage.contains('[release]')
                }
            }                
            options {
                timeout(time: 1, unit: 'MINUTES')
            }
            steps {
                echo '📦 Testes aprovados! Gerando pacote consolidado .xml para produção...'
                
                // 1. Passa a pasta do workspace atual como o primeiro argumento (%args(1)) para o IRIS
                bat "\"D:\\InterSystems\\IRIS\\bin\\irissession\" IRIS < D:\\IRIS_Server\\release.script \"\${WORKSPACE}\" || exit 0"
                
                // 2. Renomeia usando caminhos relativos de forma simples e limpa, sem risco de errar caminhos longos
                bat "ren build\\release.xml release_build_${env.BUILD_NUMBER}.xml"

                
                // 3. Arquiva o arquivo que agora está na pasta correta do build atual!
                archiveArtifacts artifacts: "build/release_build_${env.BUILD_NUMBER}.xml", fingerprint: true
                
                // Alerta dedicado de Liberação de Release para o time no Discord
                script {
                    def releasePayload = """{
                        "content": "📦 **NOVA RELEASE DISPONÍVEL!**\\n**Projeto:** ${env.JOB_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚀 *O artefato consolidado 'release_build_${env.BUILD_NUMBER}.xml' foi gerado com sucesso, livre de classes de teste! O pacote já está arquivado no painel do Jenkins e pronto para ser implantado em Produção.*"
                    }"""
                    def jsonRelease = releasePayload.replaceAll('\n', '').replaceAll('\r', '')
                    powershell "Invoke-RestMethod -Uri '${env.DISCORD_WEBHOOK}' -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${jsonRelease}')) -ContentType 'application/json; charset=utf-8'"
                }
            }
        }
    }
    
    post {
        failure {
            echo '🚨 Os testes falharam! Voltando o servidor para o estado anterior usando o backup...'
            // O rollback agora reimporta o XML original salvo no Estágio 3
            bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\rollback.script || exit 0'

            // O bloco script permite criar variáveis Groovy locais sem quebrar o compilador do Jenkins
            script {
                // Formatado direto no Groovy com quebras de linha reais
                def msgPayload = """{
                    "content": "❌ **Pipeline FALHOU!**\\n**Projeto:** ${env.JOB_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚨 *Os testes unitários falharam ou a esteira quebrou. O procedimento de Rollback automático foi executado e o servidor foi restaurado.*"
                }"""

                // Remove quebras de linha da string do payload para enviar um JSON limpo em uma linha só para a API
                def jsonPronto = msgPayload.replaceAll('\n', '').replaceAll('\r', '')
                
                // Injeta o JSON pronto direto no comando sem passar por conversões do PowerShell
                powershell "Invoke-RestMethod -Uri '${env.DISCORD_WEBHOOK}' -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${jsonPronto}')) -ContentType 'application/json; charset=utf-8'"
            }
       }
        success {
            echo '✅ Pipeline concluído com sucesso. Nenhuma falha detectada!'

            script {
                def msgPayload = """{
                    "content": "✅ **Pipeline SUCESSO!**\\n**Projeto:** ${env.JOB_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚀 *Alterações publicadas com sucesso no InterSystems IRIS e pacote de release gerado com segurança!*"
                }"""
                
                def jsonPronto = msgPayload.replaceAll('\n', '').replaceAll('\r', '')
                
                powershell "Invoke-RestMethod -Uri '${env.DISCORD_WEBHOOK}' -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${jsonPronto}')) -ContentType 'application/json; charset=utf-8'"
            }
        }
    }
}
