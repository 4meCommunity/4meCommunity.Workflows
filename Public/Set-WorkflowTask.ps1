Function Set-WorkflowTask
{
    Param
    (
        [Parameter(Mandatory = $True, ParameterSetName = "Credential")]
        [Parameter(Mandatory = $True, ParameterSetName = "Plain")]
        [Parameter(Mandatory = $True, ParameterSetName = "PAT")]
        [String] $AccountName,

        [Parameter(Mandatory = $True, ParameterSetName = "Credential")]
        [Parameter(Mandatory = $True, ParameterSetName = "Plain")]
        [Parameter(Mandatory = $True, ParameterSetName = "PAT")]
        [ValidateSet('Production', "Quality", "Demo")]
        [String] $EnvironmentType,

        [Parameter(Mandatory = $True, ParameterSetName = "Credential")]
        [Parameter(Mandatory = $True, ParameterSetName = "Plain")]
        [Parameter(Mandatory = $True, ParameterSetName = "PAT")]
        [ValidateSet('EU', 'AU', 'UK', 'US', 'CH')]
        [String] $EnvironmentRegion,
    
        [Parameter(Mandatory = $True, ParameterSetName = "Credential")]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $True, ParameterSetName = "Plain")]
        [String] $ClientId,

        [Parameter(Mandatory = $True, ParameterSetName = "Plain")]
        [String] $ClientSecret,

        [Parameter(Mandatory = $True, ParameterSetName = "PAT")]
        [String] $PersonalAccessToken,

        [Parameter(Mandatory = $True, HelpMessage = "NodeID of the task in the workflow")]
        [ValidateNotNullOrEmpty()]
        [String] $TaskId,

        [Parameter(Mandatory = $False, HelpMessage = "See https://developer.4me.com/graphql/scalar/taskstatus/ for full list")]
        [ValidateSet('registered', 'declined', 'assigned', 'accepted', 'in_progress', 'waiting_for', 'waiting_for_customer', 'request_pending', 'failed', 'rejected', 'completed', 'approved', 'canceled')]
        [String] $Status,

        [Parameter(Mandatory = $False)]
        [String] $Note,

        [Parameter(Mandatory = $False)]
        [HashTable] $Properties
    )
    
    Begin
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Start"

        If (-not $PSBoundParameters.ContainsKey("Status") -and -not $PSBoundParameters.ContainsKey("Note") -and (-not $PSBoundParameters.ContainsKey("Properties") -or $Properties.Count -eq 0))
        {
            Write-Error "Nothing to update on task. Specify -Status and -Note or other properties via -Properties to invoke an update"
        }
        ElseIf (($PSBoundParameters.ContainsKey("Status") -or $PSBoundParameters.ContainsKey("Note")) -and $PSBoundParameters.ContainsKey("Properties"))
        {
            Write-Error "Cannot use -Status or -Note with -Properties at the same time. Specify note and status inside -Properties"
        }
        ElseIf ($PSBoundParameters.ContainsKey("id"))
        {
            Write-Error "Cannot use id inside -Properties. Specify Task NodeId with -TaskId"
        }

        $Variables = @{
            "nodeId" = $TaskId
        }

        $Query = 'mutation($nodeId: ID!, @PARAMETERS@) {
taskUpdate(input: {
    id: $nodeId,
    @INPUT@
}) {
    clientMutationId
    errors {
        message
        path
    }
    task {
        id
        status
    }
}
}'
        If ($PSBoundParameters.ContainsKey("Properties"))
        {
            $parameters = ""
            $inputParameters = ""
            ForEach ($property In $Properties.GetEnumerator())
            {
                Write-Verbose "[$($MyInvocation.MyCommand.Name)] Adding $($property.Key) as $($property.Value.Type)"
                $parameters += "`$$($property.Key): $($property.Value.Type), "
                $inputParameters += "$($property.Key): `$$($property.Key), "
                $Variables.Add($($property.Key), $($property.Value.Value)) | Out-Null
            }

            $parameters = $parameters.Substring(0, $parameters.Length - 2)
            $inputParameters = $inputParameters.Substring(0, $inputParameters.Length - 2)

            $Query = $Query.Replace("@PARAMETERS@", $parameters).Replace("@INPUT@", $inputParameters)
        }
        Else
        {
            $Variables.Add('status', $Status) | Out-Null
            $Variables.Add('note', $Note) | Out-Null

            $Query = $Query.Replace("@PARAMETERS@", '$status: TaskStatus, $note: String').Replace("@INPUT@", 'status: $status,
    note: $note')
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Formed Query: $Query"
    }

    Process
    {
        $AccessToken = $PersonalAccessToken
        Switch ($PSCmdlet.ParameterSetName)
        {
            'Credential'
            {
                $AccessToken = Get-4meAccessToken -EnvironmentType $EnvironmentType -EnvironmentRegion $EnvironmentRegion -Credential $Credential
                Break
            }
            'Plain'
            {
                $AccessToken = Get-4meAccessToken -EnvironmentType $EnvironmentType -EnvironmentRegion $EnvironmentRegion -ClientId $ClientId -ClientSecret $ClientSecret
            }
        }

        $GraphQLUrl = Get-4meGraphQLUrl -EnvironmentType $EnvironmentType -EnvironmentRegion $EnvironmentRegion
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] GraphQL Url: $GraphQLUrl"

        $Headers = @{
            "X-4me-Account" = $AccountName
            "Authorization" = "Bearer $($AccessToken)"
        }

        $Response = Invoke-GraphQLMutation -Uri $GraphQLUrl -Headers $Headers -Query $Query -Variables ($Variables | ConvertTo-Json )

        If ($Null -ne $Response.errors)
        {
            ForEach ($graphError in $Response.errors)
            {
                Write-Error "$($graphError.message)"
            }
        }

        Return $Response
    }

    End
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] End"
    }
}