pipeline {
    agent any

    environment {
        // Cole sua URL aqui dentro das aspas simples
        DISCORD_WEBHOOK = 'https://discord.com/api/webhooks/1553329772543610890/pMp6AamcySFXHb_yGygY5psvOaOMNJkr4ENyd9i23OZ7pGfep7jQ00LgtSw0U9pl24d0'
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
                        def commitMessage = bat(script: 'git log -1 --pretty=%B', returnStdout: true).trim()
                        return !commitMessage.contains('[skip test]') && !commitMessage.contains('[skip ci]')
                    }
                }
            }
            options {
                timeout(time: 1, unit: 'MINUTES')
            }
            steps {
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\testes.script'
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
                powershell "Invoke-RestMethod -Uri '${env.DISCORD_WEBHOOK}' -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${msgPayload.replaceAll('\n', '').replaceAll('\r', '')}')) -ContentType 'application/json; charset=utf-8'"
            }
       }
        success {
            echo '✅ Pipeline concluído com sucesso. Nenhuma falha detectada!'

            script {
                def msgPayload = """{
                    "content": "✅ **Pipeline SUCESSO!**\\n**Projeto:** ${env.JOB_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚀 *Alterações publicadas com sucesso no InterSystems IRIS e pacote de release gerado com segurança!*"
                }"""
                
                def jsonPronto = msgPayload.replaceAll('\n', '').replaceAll('\r', '')
                
                powershell "Invoke-RestMethod -Uri '${env.DISCORD_WEBHOOK}' -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${msgPayload.replaceAll('\n', '').replaceAll('\r', '')}')) -ContentType 'application/json; charset=utf-8'"
            }
        }
    }
}
