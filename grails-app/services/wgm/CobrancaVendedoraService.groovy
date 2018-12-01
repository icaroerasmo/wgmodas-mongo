package wgm

import grails.gorm.services.Service

@Service(CobrancaVendedora)
interface CobrancaVendedoraService {

    CobrancaVendedora get(Serializable id)

    List<CobrancaVendedora> list(Map args)

    Long count()

    void delete(Serializable id)

    CobrancaVendedora save(CobrancaVendedora cobrancaVendedora)

}