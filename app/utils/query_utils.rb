##
# utility methods to deal with RedShift query data structures
#
class QueryUtils
  ##
  # query text is probably stored in the most unintuitive way
  # possible in RedShift. This method is an attempt to get the
  # individual entries merged properly.
  # just give us one effing system table with the part merged!!!
  # while we're at it unique identifiers for all query types would
  # also be nice and make this merge more straightforward.
  # to make things worse the sequences seem to swallow one or two characters
  # for specific queries (completed queries from polizei) at their boundaries ...
  #
  # WARN: if +queries_sequences+ is sorted improperly, this will
  # just return garbage.
  # +queries_sequences+ needs to have all sequences of a query in ascending
  # order without gaps or sequences of other queries in between in
  # the list.
  #
  def self.sequence_merge(queries_sequences)
    new_queries_sequences = []
    tmp = nil
    queries_sequences.each do |qs|
      if qs['sequence'].to_i == 0
        new_queries_sequences << tmp unless tmp.nil?
        tmp = qs
        tmp.delete('sequence')
      else
        tmp['query'] += qs['query']
      end
    end
    new_queries_sequences << tmp unless tmp.nil?
    return new_queries_sequences
  end
end
