pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
        timeout(time: 1, unit: 'HOURS')
    }

    environment {
        DISCORD_WEBHOOK_ID = 'discord-webhook-url'
    }
    
    stages {
        stage('1. Baixar do GitHub') {
            steps {
                echo '📥 Baixando a última versão do código fonte via Git...'
                checkout scm
            }
        }
        
        stage('2. Copiar para o Servidor') {
            steps {
                echo '🧹 Atualizando apenas os arquivos de código no servidor local...'
                bat 'del /q /s D:\\IRIS_Server\\projectGit\\src\\* 2>nul || exit 0'
                bat 'del /q /s D:\\IRIS_Server\\projectGit\\tests\\* 2>nul || exit 0'
                bat 'xcopy /E /Y . D:\\IRIS_Server\\projectGit\\'
            }
        }
        
        stage('3. Backup e Deploy no IRIS') {
            options {
                timeout(time: 30, unit: 'MINUTES') 
            }
            
            steps {
                echo '📦 Criando snapshot de segurança e aplicando novo código fonte no pacote src...'
                
                script {

                    // ========================================
                    // Gera o script que será executado no IRIS
                    // ========================================
                    def importarScriptConteudo = "zn \"USER\"\n" +
                                                "set arquivoBackup=\"D:\\\\IRIS_Server\\\\backup_anterior.xml\"\n" +
                                                "set arquivoStatus=\"D:\\\\IRIS_Server\\\\deploy_status.txt\"\n" +
                                                "set pacoteAlvo=\"src\"\n" +
                                                "do \$SYSTEM.OBJ.ExportPackage(pacoteAlvo, arquivoBackup, \"-d\")\n" +
                                                "set sc=\$SYSTEM.OBJ.LoadDir(\"D:/IRIS_Server/projectGit/src/\", \"ck\", , 1)\n" +
                                                "write \"STATUS LOADDIR: \",sc,!\n" +
                                                "if 'sc write \"ERRO_LOADDIR: \",\$SYSTEM.Status.GetErrorText(sc),!\n" +
                                                "if 'sc open arquivoStatus use arquivoStatus write \"ERROR\",! close\n" +
                                                "if sc open arquivoStatus use arquivoStatus write \"OK\",! close\n" +
                                                "halt\n"

                    writeFile(
                        file: 'scripts/importar.script',
                        text: importarScriptConteudo,
                        encoding: 'UTF-8'
                    )


                    // ========================================
                    // Remove resultado anterior
                    // ========================================
                    bat '''
                        if exist "D:\\IRIS_Server\\deploy_status.txt" del /q "D:\\IRIS_Server\\deploy_status.txt"
                    '''


                    // ========================================
                    // Executa o IRIS
                    // ========================================
                    def exitCode = bat(
                        returnStatus: true,
                        script: '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < scripts\\importar.script'
                    )

                    echo "========================================"
                    echo "IRIS SESSION - EXIT CODE: ${exitCode}"
                    echo "========================================"


                    // ========================================
                    // Verifica se o IRIS criou o arquivo
                    // ========================================
                    def arquivoExiste = bat(
                        returnStatus: true,
                        script: 'if exist "D:\\IRIS_Server\\deploy_status.txt" (exit /b 0) else (exit /b 1)'
                    )

                    if (arquivoExiste != 0) {
                        error "O IRIS não gerou o arquivo deploy_status.txt."
                    }


                    // ========================================
                    // Lê o resultado gerado pelo IRIS
                    // ========================================
                    def statusDeploy = bat(
                        returnStdout: true,
                        script: '@type "D:\\IRIS_Server\\deploy_status.txt"'
                    ).trim()

                    echo "========================================"
                    echo "STATUS DO DEPLOY IRIS: ${statusDeploy}"
                    echo "========================================"


                    // ========================================
                    // Decide se o deploy foi bem-sucedido
                    // ========================================
                    if (statusDeploy != 'OK') {
                        error "O IRIS informou falha durante o deploy."
                    }

                    echo "========================================"
                    echo "DEPLOY REALIZADO COM SUCESSO"
                    echo "========================================"
                }
            }
        }
        
        stage('4. Executar Testes Unitários') {            
            when {
                allOf {
                    expression { return fileExists('tests') }
                    not { branch 'production' }
                    expression { 
                        def changeLogSets = currentBuild.changeSets
                        def commitMessage = changeLogSets.collect { set -> 
                            set.items.collect { item -> item.msg }.join(' ') 
                        }.join(' ')

                        return !commitMessage.contains('[skip test]') &&
                               !commitMessage.contains('[skip ci]')
                    }
                }
            }

            options {
                timeout(time: 10, unit: 'MINUTES')
            }

            steps {
                echo '🧪 Executando bateria de testes unitários com retenção inteligente...'
                
                script {
                    def irisWorkspacePath = "${WORKSPACE}".replace('\\', '/')
                    
                    def testeScriptConteudo = "zn \"USER\"\n" +
                                              "set primeiroId=\$order(^UnitTest.Result(\"\"))\n" +
                                              "if primeiroId'=\"\" { set dataCriacao=\$listget(\$get(^UnitTest.Result(primeiroId)), 1) if dataCriacao'=\"\" { set dataH=\$zdatetimeh(dataCriacao, 3, 1) set diasAntigo=\$piece(dataH, \",\", 1) set diasHoje=\$piece(\$horolog, \",\", 1) if (diasHoje - diasAntigo) >= 7 { do ##class(%UnitTest.Result.TestInstance).%DeleteExtent() } } }\n" +
                                              "set ^UnitTestRoot=\"${irisWorkspacePath}\"\n" +
                                              "set sc=##class(%UnitTest.Manager).RunTest(\"tests\", \"/load/compile\")\n" +
                                              "set lastId=\$order(^UnitTest.Result(\"\"), -1)\n" +
                                              "set statusValido=1\n" +
                                              "if lastId'=\"\" { set dadosSuite=\$get(^UnitTest.Result(lastId, \"tests\")) if dadosSuite'=\"\" set statusValido=\$listget(dadosSuite, 1) }\n" +
                                              "if ('sc) || (statusValido=0) hang 2 halt\n" +
                                              "halt\n"

                    writeFile file: 'scripts/executar_testes.script',
                              text: testeScriptConteudo,
                              encoding: 'UTF-8'
                }

                script {
                    try {
                        echo '▶️ Iniciando irissession para execução dos testes...'

                        def exitCode = bat(
                            returnStatus: true,
                            script: '''
                                "D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < scripts\\executar_testes.script

                                echo.
                                echo ========================================
                                echo ERRORLEVEL DO IRISSESSION: %ERRORLEVEL%
                                echo ========================================

                                exit /b %ERRORLEVEL%
                            '''
                        )

                        echo "========================================"
                        echo "IRIS TESTES - EXIT CODE: ${exitCode}"
                        echo "========================================"

                        if (exitCode != 0) {
                            error "O irissession retornou código de saída ${exitCode} após a execução dos testes."
                        }

                        echo '✅ irissession retornou código 0. Testes concluídos sem erro de processo.'

                    } catch (Exception e) {
                        echo "========================================"
                        echo "ERRO NO ESTÁGIO DE TESTES"
                        echo "========================================"
                        echo "Tipo da exceção: ${e.getClass().getName()}"
                        echo "Mensagem: ${e.getMessage()}"
                        echo "Resultado atual do build: ${currentBuild.result}"
                        echo "========================================"

                        throw e
                    }
                }
            }
        }
        
        stage('5. Gerar Artefato de Release') {
            when {
                expression { 
                    def changeLogSets = currentBuild.changeSets
                    def commitMessage = changeLogSets.collect { set -> 
                        set.items.collect { item -> item.msg }.join(' ') 
                    }.join(' ')

                    if (!commitMessage || commitMessage.trim() == "") {
                        commitMessage = powershell(
                            script: "git log -1 --pretty=format:%B",
                            returnStdout: true
                        ).trim()
                    }

                    return commitMessage.contains('[release]')
                }
            }
            
            options {
                timeout(time: 1, unit: 'MINUTES')
            }

            steps {
                echo '📦 Testes aprovados com louvor! Exportando pacote consolidado .xml para implantação...'
                
                script {
                    def irisWorkspacePath = "${WORKSPACE}".replace('\\', '/')
                    
                    def scriptConteudo = "zn \"USER\"\n" +
                                         "set arquivoRelease=\"${irisWorkspacePath}/build/release.xml\"\n" +
                                         "set classesParaExportar=\"src.*.cls\"\n" +
                                         "set sc=\$SYSTEM.OBJ.Export(classesParaExportar,arquivoRelease,\"-d\")\n" +
                                         "halt\n"

                    writeFile file: 'scripts/gerar_release.script',
                              text: scriptConteudo,
                              encoding: 'UTF-8'
                }
                
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < scripts\\gerar_release.script || exit 0'

                bat 'mkdir D:\\IRIS_Server\\build 2>nul || exit 0'

                bat "move build\\release.xml D:\\IRIS_Server\\build\\release_build_${env.BUILD_NUMBER}.xml"

                archiveArtifacts artifacts: "build/release_build_${env.BUILD_NUMBER}.xml",
                                 fingerprint: true
                
                withCredentials([
                    string(
                        credentialsId: env.DISCORD_WEBHOOK_ID,
                        variable: 'WEBHOOK_SECRET'
                    )
                ]) {
                    script {
                        powershell """
                            \$corpo = @{
                                content = "📦 **NOVA RELEASE DISPONÍVEL!**`n**Projeto:** ${env.JOB_NAME}`n**Branch:** ${env.BRANCH_NAME}`n**Build:** #${env.BUILD_NUMBER}`n🚀 *O artefato consolidado release_build_${env.BUILD_NUMBER}.xml foi gerado com sucesso! O pacote está seguro na pasta externa D:\\\\IRIS_Server\\\\build e arquivado no Jenkins.*"
                            } | ConvertTo-Json -Compress

                            Invoke-RestMethod `
                                -Uri \$env:WEBHOOK_SECRET `
                                -Method Post `
                                -Body ([System.Text.Encoding]::UTF8.GetBytes(\$corpo)) `
                                -ContentType 'application/json; charset=utf-8'
                        """
                    }
                }
            }
        }
    }
    
    post {
        failure {
            echo '🚨 O build falhou ou os testes quebraram! Executando Rollback automático via ObjectScript...'

            script {
                def rollbackScriptConteudo = "zn \"USER\"\n" +
                                             "set arquivoBackup=\"D:\\\\IRIS_Server\\\\backup_anterior.xml\"\n" +
                                             "if ##class(%File).Exists(arquivoBackup) set sc=\$SYSTEM.OBJ.Load(arquivoBackup, \"ck\")\n" +
                                             "halt\n"

                writeFile file: 'scripts/rollback.script',
                          text: rollbackScriptConteudo,
                          encoding: 'UTF-8'
            }

            bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < scripts\\rollback.script || exit 0'

            withCredentials([
                string(
                    credentialsId: env.DISCORD_WEBHOOK_ID,
                    variable: 'WEBHOOK_SECRET'
                )
            ]) {
                script {
                    powershell """
                        \$corpo = @{
                            content = "❌ **Pipeline FALHOU!**`n**Projeto:** ${env.JOB_NAME}`n**Branch:** ${env.BRANCH_NAME}`n**Build:** #${env.BUILD_NUMBER}`n🚨 *Os testes unitários falharam ou a esteira quebrou. O procedimento de Rollback automático foi executado e o ambiente local foi restaurado.*"
                        } | ConvertTo-Json -Compress

                        Invoke-RestMethod `
                            -Uri \$env:WEBHOOK_SECRET `
                            -Method Post `
                            -Body ([System.Text.Encoding]::UTF8.GetBytes(\$corpo)) `
                            -ContentType 'application/json; charset=utf-8'
                    """
                }
            }
        }

        success {
            echo '✅ Pipeline concluído com sucesso total. Nenhuma inconsistência detectada!'

            withCredentials([
                string(
                    credentialsId: env.DISCORD_WEBHOOK_ID,
                    variable: 'WEBHOOK_SECRET'
                )
            ]) {
                script {
                    powershell """
                        \$corpo = @{
                            content = "✅ **Pipeline SUCESSO!**`n**Projeto:** ${env.JOB_NAME}`n**Branch:** ${env.BRANCH_NAME}`n**Build:** #${env.BUILD_NUMBER}`n🚀 *Alterações publicadas com sucesso no InterSystems IRIS e pacote de release gerado com segurança!*"
                        } | ConvertTo-Json -Compress

                        Invoke-RestMethod `
                            -Uri \$env:WEBHOOK_SECRET `
                            -Method Post `
                            -Body ([System.Text.Encoding]::UTF8.GetBytes(\$corpo)) `
                            -ContentType 'application/json; charset=utf-8'
                    """
                }
            }
        }
    }
}